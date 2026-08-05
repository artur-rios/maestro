#pragma once

#include <windows.h>

#include <stdexcept>
#include <string>

class CA2W {
 public:
  explicit CA2W(const char* value) : value_(Convert(value)) {
    m_psz = value_.data();
  }

  wchar_t* m_psz;

 private:
  static std::wstring Convert(const char* value) {
    if (value == nullptr) {
      return std::wstring();
    }
    const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value,
                                         -1, nullptr, 0);
    if (size == 0) {
      throw std::runtime_error("UTF-8 to UTF-16 conversion failed");
    }
    std::wstring result(static_cast<size_t>(size), L'\0');
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value, -1,
                            result.data(), size) == 0) {
      throw std::runtime_error("UTF-8 to UTF-16 conversion failed");
    }
    result.resize(static_cast<size_t>(size - 1));
    return result;
  }

  std::wstring value_;
};

class CW2A {
 public:
  explicit CW2A(const wchar_t* value) : value_(Convert(value)) {}

  operator const char*() const { return value_.c_str(); }

 private:
  static std::string Convert(const wchar_t* value) {
    if (value == nullptr) {
      return std::string();
    }
    const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value,
                                         -1, nullptr, 0, nullptr, nullptr);
    if (size == 0) {
      throw std::runtime_error("UTF-16 to UTF-8 conversion failed");
    }
    std::string result(static_cast<size_t>(size), '\0');
    if (WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value, -1,
                            result.data(), size, nullptr, nullptr) == 0) {
      throw std::runtime_error("UTF-16 to UTF-8 conversion failed");
    }
    result.resize(static_cast<size_t>(size - 1));
    return result;
  }

  std::string value_;
};
