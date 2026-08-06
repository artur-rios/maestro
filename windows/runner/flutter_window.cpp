#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <UserConsentVerifierInterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Security.Credentials.UI.h>

#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <utility>

#include "flutter/generated_plugin_registrant.h"

class AuthenticationReplyGate {
 public:
  template <typename Reply>
  void ReplyIfActive(Reply&& reply) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (active_) {
      std::forward<Reply>(reply)();
    }
  }

  void Deactivate() {
    std::lock_guard<std::mutex> lock(mutex_);
    active_ = false;
  }

 private:
  std::mutex mutex_;
  bool active_ = true;
};

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodResult;
using winrt::Windows::Foundation::IAsyncOperation;
using winrt::Windows::Security::Credentials::UI::UserConsentVerificationResult;
using winrt::Windows::Security::Credentials::UI::UserConsentVerifier;
using winrt::Windows::Security::Credentials::UI::UserConsentVerifierAvailability;
using WinrtAsyncStatus = winrt::Windows::Foundation::AsyncStatus;

constexpr char kAuthenticationChannel[] =
    "dev.artur-rios.maestro/authentication";

EncodableValue AuthenticationResponse(
    const std::string& status,
    const std::string& message = "",
    const std::optional<std::string>& remediation = std::nullopt) {
  EncodableMap response{
      {EncodableValue("status"), EncodableValue(status)},
  };
  if (!message.empty()) {
    response[EncodableValue("message")] = EncodableValue(message);
  }
  if (remediation.has_value()) {
    response[EncodableValue("remediation")] =
        EncodableValue(remediation.value());
  }
  return EncodableValue(response);
}

EncodableValue AvailabilityResponse(UserConsentVerifierAvailability value) {
  switch (value) {
    case UserConsentVerifierAvailability::Available:
      return AuthenticationResponse(
          "available", "Operating-system authentication is available.");
    case UserConsentVerifierAvailability::DeviceNotPresent:
      return AuthenticationResponse(
          "missing", "No Windows Hello authentication device is available.",
          "Configure Windows Hello or use email and password authentication.");
    case UserConsentVerifierAvailability::NotConfiguredForUser:
      return AuthenticationResponse(
          "missing", "Windows Hello is not configured for the current user.",
          "Configure Windows Hello or use email and password authentication.");
    case UserConsentVerifierAvailability::DisabledByPolicy:
      return AuthenticationResponse(
          "denied", "Windows Hello is disabled by system policy.",
          "Contact the system administrator or use email and password "
          "authentication.");
    case UserConsentVerifierAvailability::DeviceBusy:
      return AuthenticationResponse(
          "transientFailure", "The Windows Hello device is busy.",
          "Retry or use email and password authentication.");
  }
  return AuthenticationResponse(
      "unsupported", "Windows Hello returned an unsupported availability.",
      "Use email and password authentication.");
}

EncodableValue VerificationResponse(UserConsentVerificationResult value) {
  switch (value) {
    case UserConsentVerificationResult::Verified:
      return AuthenticationResponse("authenticated");
    case UserConsentVerificationResult::RetriesExhausted:
      return AuthenticationResponse(
          "denied", "Windows Hello verification attempts were exhausted.",
          "Retry later or use email and password authentication.");
    case UserConsentVerificationResult::Canceled:
      return AuthenticationResponse(
          "denied", "Windows Hello verification was canceled.",
          "Retry or use email and password authentication.");
    case UserConsentVerificationResult::DeviceNotPresent:
      return AuthenticationResponse(
          "unavailable", "No Windows Hello authentication device is available.",
          "Configure Windows Hello or use email and password authentication.");
    case UserConsentVerificationResult::NotConfiguredForUser:
      return AuthenticationResponse(
          "unavailable", "Windows Hello is not configured for the current user.",
          "Configure Windows Hello or use email and password authentication.");
    case UserConsentVerificationResult::DisabledByPolicy:
      return AuthenticationResponse(
          "unavailable", "Windows Hello is disabled by system policy.",
          "Contact the system administrator or use email and password "
          "authentication.");
    case UserConsentVerificationResult::DeviceBusy:
      return AuthenticationResponse(
          "transientFailure", "The Windows Hello device is busy.",
          "Retry or use email and password authentication.");
  }
  return AuthenticationResponse(
      "transientFailure", "Windows Hello returned an unsupported result.",
      "Retry or use email and password authentication.");
}

EncodableValue WindowsHelloFailure() {
  return AuthenticationResponse(
      "transientFailure", "Windows Hello could not complete the request.",
      "Retry or use email and password authentication.");
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  authentication_reply_gate_ = std::make_shared<AuthenticationReplyGate>();
  RegisterPlugins(flutter_controller_->engine());

  flutter::MethodChannel<EncodableValue> authentication_channel(
      flutter_controller_->engine()->messenger(), kAuthenticationChannel,
      &flutter::StandardMethodCodec::GetInstance());
  authentication_channel.SetMethodCallHandler(
      [this](const flutter::MethodCall<EncodableValue>& call,
             std::unique_ptr<MethodResult<EncodableValue>> result) {
        auto shared_result =
            std::shared_ptr<MethodResult<EncodableValue>>(std::move(result));
        auto reply_gate = authentication_reply_gate_;
        if (call.method_name() == "probe") {
          try {
            auto operation = UserConsentVerifier::CheckAvailabilityAsync();
            operation.Completed(
                [shared_result, reply_gate](
                    const IAsyncOperation<UserConsentVerifierAvailability>&
                        completed,
                    WinrtAsyncStatus status) {
                  try {
                    auto response = status == WinrtAsyncStatus::Completed
                                        ? AvailabilityResponse(
                                              completed.GetResults())
                                        : WindowsHelloFailure();
                    reply_gate->ReplyIfActive(
                        [shared_result, response = std::move(response)]() {
                          shared_result->Success(response);
                        });
                  } catch (...) {
                    reply_gate->ReplyIfActive([shared_result]() {
                      shared_result->Success(WindowsHelloFailure());
                    });
                  }
                });
          } catch (...) {
            reply_gate->ReplyIfActive([shared_result]() {
              shared_result->Success(WindowsHelloFailure());
            });
          }
          return;
        }

        if (call.method_name() == "authenticateCurrentUser") {
          try {
            using VerificationOperation =
                IAsyncOperation<UserConsentVerificationResult>;
            auto interop = winrt::get_activation_factory<UserConsentVerifier,
                                                          IUserConsentVerifierInterop>();
            VerificationOperation operation{nullptr};
            const winrt::hstring prompt(
                L"Confirm your identity to sign in to Maestro.");
            winrt::check_hresult(interop->RequestVerificationForWindowAsync(
                GetHandle(),
                reinterpret_cast<HSTRING>(winrt::get_abi(prompt)),
                winrt::guid_of<VerificationOperation>(),
                winrt::put_abi(operation)));
            operation.Completed(
                [shared_result, reply_gate](
                    const VerificationOperation& completed,
                    WinrtAsyncStatus status) {
                  try {
                    auto response = status == WinrtAsyncStatus::Completed
                                        ? VerificationResponse(
                                              completed.GetResults())
                                        : WindowsHelloFailure();
                    reply_gate->ReplyIfActive(
                        [shared_result, response = std::move(response)]() {
                          shared_result->Success(response);
                        });
                  } catch (...) {
                    reply_gate->ReplyIfActive([shared_result]() {
                      shared_result->Success(WindowsHelloFailure());
                    });
                  }
                });
          } catch (...) {
            reply_gate->ReplyIfActive([shared_result]() {
              shared_result->Success(WindowsHelloFailure());
            });
          }
          return;
        }

        shared_result->NotImplemented();
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (authentication_reply_gate_) {
    authentication_reply_gate_->Deactivate();
  }
  if (flutter_controller_) {
    flutter::MethodChannel<EncodableValue> authentication_channel(
        flutter_controller_->engine()->messenger(), kAuthenticationChannel,
        &flutter::StandardMethodCodec::GetInstance());
    authentication_channel.SetMethodCallHandler(nullptr);
    flutter_controller_ = nullptr;
  }
  authentication_reply_gate_ = nullptr;

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
