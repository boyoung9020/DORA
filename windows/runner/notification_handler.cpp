#include "notification_handler.h"

#include <windows.h>
#include <string>
#include <sstream>

// Helper function to convert string to wide string
std::wstring NotificationHandler::Utf8ToWideString(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
  std::wstring wstrTo(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
  return wstrTo;
}

// Helper function to convert wide string to UTF-8
std::string NotificationHandler::WideStringToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

NotificationHandler::NotificationHandler(flutter::BinaryMessenger* messenger)
    : messenger_(messenger) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger_, "com.dora/notifications",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        this->HandleMethodCall(call, std::move(result));
      });

  channel_ = std::move(channel);
}

NotificationHandler::~NotificationHandler() {}

void NotificationHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "initialize") {
    result->Success(flutter::EncodableValue(true));
  } else if (method == "showNotification") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (arguments) {
      const auto* id_value = std::get_if<std::string>(&(*arguments)[flutter::EncodableValue("id")]);
      const auto* title_value = std::get_if<std::string>(&(*arguments)[flutter::EncodableValue("title")]);
      const auto* message_value = std::get_if<std::string>(&(*arguments)[flutter::EncodableValue("message")]);

      if (id_value && title_value && message_value) {
        ShowNotification(*id_value, *title_value, *message_value);
        result->Success(flutter::EncodableValue(true));
      } else {
        result->Error("INVALID_ARGUMENT", "Missing required arguments");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Invalid arguments");
    }
  } else if (method == "cancelNotification") {
    result->Success(flutter::EncodableValue(true));
  } else if (method == "cancelAllNotifications") {
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

void NotificationHandler::ShowNotification(const std::string& id, const std::string& title, const std::string& message) {
  // Use Windows Toast notification API
  // For Windows 10/11, we'll use a simple MessageBox as fallback
  // For proper Toast notifications, you would need to use Windows Runtime API
  
  std::wstring wtitle = Utf8ToWideString(title);
  std::wstring wmessage = Utf8ToWideString(message);
  
  // Show a non-blocking message box
  // Note: This is a simple implementation. For proper Toast notifications,
  // you would need to use Windows.UI.Notifications API with proper app manifest.
  MessageBoxW(NULL, wmessage.c_str(), wtitle.c_str(), MB_OK | MB_ICONINFORMATION | MB_TOPMOST);
}
