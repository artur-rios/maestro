#include "my_application.h"

#include <dlfcn.h>
#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <cstdlib>
#include <cstring>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr char kAuthenticationChannel[] =
    "dev.artur-rios.maestro/authentication";
constexpr char kPamLibrary[] = "libpam.so.0";
constexpr char kPamService[] = "login";

// Stable Linux-PAM application ABI declarations. The library is loaded at
// runtime so the runner needs no PAM development package or link-time library.
struct PamHandle;

struct PamMessage {
  int msg_style;
  const char* msg;
};

struct PamResponse {
  char* resp;
  int resp_retcode;
};

using PamConversationFunction = int (*)(int message_count,
                                        const PamMessage** messages,
                                        PamResponse** responses,
                                        void* application_data);

struct PamConversation {
  PamConversationFunction conversation;
  void* application_data;
};

using PamStartFunction = int (*)(const char* service_name,
                                 const char* user,
                                 const PamConversation* conversation,
                                 PamHandle** handle);
using PamAuthenticateFunction = int (*)(PamHandle* handle, int flags);
using PamEndFunction = int (*)(PamHandle* handle, int status);

constexpr int kPamSuccess = 0;
constexpr int kPamOpenError = 1;
constexpr int kPamSymbolError = 2;
constexpr int kPamServiceError = 3;
constexpr int kPamSystemError = 4;
constexpr int kPamBufferError = 5;
constexpr int kPamPermissionDenied = 6;
constexpr int kPamAuthenticationError = 7;
constexpr int kPamCredentialsInsufficient = 8;
constexpr int kPamAuthenticationInfoUnavailable = 9;
constexpr int kPamUserUnknown = 10;
constexpr int kPamMaximumTries = 11;
constexpr int kPamConversationError = 19;
constexpr int kPamAbort = 26;
constexpr int kPamPromptEchoOff = 1;
constexpr int kPamPromptEchoOn = 2;
constexpr int kPamErrorMessage = 3;
constexpr int kPamTextInfo = 4;
constexpr int kPamMaximumMessageCount = 32;
constexpr int kPamDisallowNullAuthenticationToken = 0x0001;

class PamApi {
 public:
  PamApi() : library_(dlopen(kPamLibrary, RTLD_NOW | RTLD_LOCAL)) {
    if (library_ == nullptr) {
      return;
    }
    start_ = reinterpret_cast<PamStartFunction>(dlsym(library_, "pam_start"));
    authenticate_ = reinterpret_cast<PamAuthenticateFunction>(
        dlsym(library_, "pam_authenticate"));
    end_ = reinterpret_cast<PamEndFunction>(dlsym(library_, "pam_end"));
    if (start_ == nullptr || authenticate_ == nullptr || end_ == nullptr) {
      dlclose(library_);
      library_ = nullptr;
      start_ = nullptr;
      authenticate_ = nullptr;
      end_ = nullptr;
    }
  }

  ~PamApi() {
    if (library_ != nullptr) {
      dlclose(library_);
    }
  }

  PamApi(const PamApi&) = delete;
  PamApi& operator=(const PamApi&) = delete;

  bool is_available() const { return library_ != nullptr; }

  int Start(const char* service_name,
            const char* user,
            const PamConversation* conversation,
            PamHandle** handle) const {
    return start_(service_name, user, conversation, handle);
  }

  int Authenticate(PamHandle* handle, int flags) const {
    return authenticate_(handle, flags);
  }

  int End(PamHandle* handle, int status) const {
    return end_(handle, status);
  }

 private:
  void* library_ = nullptr;
  PamStartFunction start_ = nullptr;
  PamAuthenticateFunction authenticate_ = nullptr;
  PamEndFunction end_ = nullptr;
};

struct PamConversationContext {
  GtkWindow* parent;
  bool canceled;
};

void ClearString(char* value) {
  if (value == nullptr) {
    return;
  }
  volatile char* cursor = value;
  while (*cursor != '\0') {
    *cursor++ = '\0';
  }
}

void FreeResponses(PamResponse* responses, int response_count) {
  if (responses == nullptr) {
    return;
  }
  for (int index = 0; index < response_count; ++index) {
    ClearString(responses[index].resp);
    free(responses[index].resp);
  }
  free(responses);
}

void ClearEntries(const std::vector<GtkWidget*>& entries) {
  for (GtkWidget* entry : entries) {
    if (entry != nullptr) {
      gtk_entry_set_text(GTK_ENTRY(entry), "");
    }
  }
}

int ShowPamConversation(int message_count,
                        const PamMessage** messages,
                        PamResponse** responses,
                        void* application_data) {
  if (message_count <= 0 || message_count > kPamMaximumMessageCount ||
      messages == nullptr || responses == nullptr || application_data == nullptr) {
    return kPamConversationError;
  }

  auto* context = static_cast<PamConversationContext*>(application_data);
  GtkWidget* dialog = gtk_dialog_new_with_buttons(
      "Authenticate to Maestro", context->parent,
      static_cast<GtkDialogFlags>(GTK_DIALOG_MODAL |
                                  GTK_DIALOG_DESTROY_WITH_PARENT),
      "_Cancel", GTK_RESPONSE_CANCEL, "_Authenticate", GTK_RESPONSE_OK,
      nullptr);
  gtk_dialog_set_default_response(GTK_DIALOG(dialog), GTK_RESPONSE_OK);
  GtkWidget* content = gtk_dialog_get_content_area(GTK_DIALOG(dialog));
  gtk_container_set_border_width(GTK_CONTAINER(content), 16);
  std::vector<GtkWidget*> entries(message_count, nullptr);

  for (int index = 0; index < message_count; ++index) {
    if (messages[index] == nullptr) {
      gtk_widget_destroy(dialog);
      return kPamConversationError;
    }
    const char* message = messages[index]->msg == nullptr
                              ? "Operating-system credentials"
                              : messages[index]->msg;
    GtkWidget* label = gtk_label_new(message);
    gtk_label_set_line_wrap(GTK_LABEL(label), TRUE);
    gtk_label_set_xalign(GTK_LABEL(label), 0.0F);
    gtk_box_pack_start(GTK_BOX(content), label, FALSE, FALSE, 4);

    switch (messages[index]->msg_style) {
      case kPamPromptEchoOff:
      case kPamPromptEchoOn: {
        GtkWidget* entry = gtk_entry_new();
        gtk_entry_set_visibility(
            GTK_ENTRY(entry),
            messages[index]->msg_style == kPamPromptEchoOn);
        gtk_entry_set_activates_default(GTK_ENTRY(entry), TRUE);
        gtk_box_pack_start(GTK_BOX(content), entry, FALSE, FALSE, 4);
        entries[index] = entry;
        break;
      }
      case kPamErrorMessage:
      case kPamTextInfo:
        break;
      default:
        gtk_widget_destroy(dialog);
        return kPamConversationError;
    }
  }

  gtk_widget_show_all(dialog);
  const gint dialog_result = gtk_dialog_run(GTK_DIALOG(dialog));
  if (dialog_result != GTK_RESPONSE_OK) {
    context->canceled = true;
    ClearEntries(entries);
    gtk_widget_destroy(dialog);
    return kPamConversationError;
  }

  auto* pam_responses = static_cast<PamResponse*>(
      calloc(static_cast<size_t>(message_count), sizeof(PamResponse)));
  if (pam_responses == nullptr) {
    ClearEntries(entries);
    gtk_widget_destroy(dialog);
    return kPamBufferError;
  }

  for (int index = 0; index < message_count; ++index) {
    if (entries[index] == nullptr) {
      continue;
    }
    const char* text = gtk_entry_get_text(GTK_ENTRY(entries[index]));
    pam_responses[index].resp = strdup(text);
    if (pam_responses[index].resp == nullptr) {
      ClearEntries(entries);
      FreeResponses(pam_responses, message_count);
      gtk_widget_destroy(dialog);
      return kPamBufferError;
    }
  }

  // Linux-PAM owns and frees successful pam_response buffers after this
  // callback. Clear GTK's separate credential copy before transferring them.
  ClearEntries(entries);
  gtk_widget_destroy(dialog);
  *responses = pam_responses;
  return kPamSuccess;
}

FlValue* AuthenticationResponse(const char* status,
                                const char* message = nullptr,
                                const char* remediation = nullptr) {
  FlValue* response = fl_value_new_map();
  fl_value_set_string_take(response, "status", fl_value_new_string(status));
  if (message != nullptr) {
    fl_value_set_string_take(response, "message", fl_value_new_string(message));
  }
  if (remediation != nullptr) {
    fl_value_set_string_take(response, "remediation",
                             fl_value_new_string(remediation));
  }
  return response;
}

void Respond(FlMethodCall* method_call,
             const char* status,
             const char* message = nullptr,
             const char* remediation = nullptr) {
  g_autoptr(FlValue) response =
      AuthenticationResponse(status, message, remediation);
  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond_success(method_call, response, &error)) {
    g_warning("Failed to send authentication response: %s", error->message);
  }
}

void ProbeAuthentication(FlMethodCall* method_call) {
  PamApi pam;
  if (pam.is_available()) {
    Respond(method_call, "available",
            "Operating-system authentication is available.");
    return;
  }
  Respond(method_call, "missing", "The Linux PAM service is unavailable.",
          "Install the operating-system PAM runtime or use email and password "
          "authentication.");
}

void AuthenticateCurrentUser(GtkWindow* parent, FlMethodCall* method_call) {
  PamApi pam;
  if (!pam.is_available()) {
    Respond(method_call, "unavailable", "The Linux PAM service is unavailable.",
            "Install the operating-system PAM runtime or use email and password "
            "authentication.");
    return;
  }

  const char* user = g_get_user_name();
  if (user == nullptr || user[0] == '\0') {
    Respond(method_call, "unavailable",
            "The current Linux user could not be determined.",
            "Use email and password authentication.");
    return;
  }

  PamConversationContext context{parent, false};
  const PamConversation conversation{ShowPamConversation, &context};
  PamHandle* handle = nullptr;
  int status = pam.Start(kPamService, user, &conversation, &handle);
  if (status == kPamSuccess) {
    status = pam.Authenticate(handle, kPamDisallowNullAuthenticationToken);
    pam.End(handle, status);
  }

  if (status == kPamSuccess) {
    Respond(method_call, "authenticated");
    return;
  }
  if (context.canceled || status == kPamPermissionDenied ||
      status == kPamAuthenticationError || status == kPamUserUnknown ||
      status == kPamMaximumTries) {
    Respond(method_call, "denied",
            context.canceled ? "Operating-system authentication was canceled."
                             : "Operating-system credentials were not verified.",
            "Retry or use email and password authentication.");
    return;
  }
  if (status == kPamOpenError || status == kPamSymbolError ||
      status == kPamServiceError ||
      status == kPamAuthenticationInfoUnavailable ||
      status == kPamCredentialsInsufficient) {
    Respond(method_call, "unavailable",
            "The Linux PAM authentication service is unavailable.",
            "Repair the system authentication configuration or use email and "
            "password authentication.");
    return;
  }
  if (status == kPamSystemError || status == kPamBufferError ||
      status == kPamConversationError || status == kPamAbort) {
    Respond(method_call, "transientFailure",
            "Linux PAM could not complete authentication.",
            "Retry or use email and password authentication.");
    return;
  }
  Respond(method_call, "transientFailure",
          "Linux PAM returned an unsupported authentication result.",
          "Retry or use email and password authentication.");
}

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* authentication_channel;
  GtkWindow* window;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void authentication_method_call_cb(FlMethodChannel* channel,
                                          FlMethodCall* method_call,
                                          gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const char* name = fl_method_call_get_name(method_call);
  if (g_str_equal(name, "probe")) {
    ProbeAuthentication(method_call);
  } else if (g_str_equal(name, "authenticateCurrentUser")) {
    AuthenticateCurrentUser(self->window, method_call);
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  self->window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(self->window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Maestro");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(self->window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(self->window, "Maestro");
  }

  gtk_window_set_default_size(self->window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(self->window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  FlEngine* engine = fl_view_get_engine(view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->authentication_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(engine), kAuthenticationChannel,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->authentication_channel, authentication_method_call_cb, self,
      nullptr);

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  if (self->authentication_channel != nullptr) {
    fl_method_channel_set_method_call_handler(self->authentication_channel,
                                              nullptr, nullptr, nullptr);
  }
  g_clear_object(&self->authentication_channel);
  self->window = nullptr;
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
