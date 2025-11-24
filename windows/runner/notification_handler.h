#ifndef RUNNER_NOTIFICATION_HANDLER_H_
#define RUNNER_NOTIFICATION_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/binary_messenger.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <memory>
#include <string>

// Windows Toast notification handler
class NotificationHandler {
 public:
  explicit NotificationHandler(flutter::BinaryMessenger* messenger);
  ~NotificationHandler();

  // Handle platform channel method calls
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  // Show Windows Toast notification
  void ShowNotification(const std::string& id, const std::string& title, const std::string& message);
  std::string WideStringToUtf8(const std::wstring& wstr);
  std::wstring Utf8ToWideString(const std::string& str);

  flutter::BinaryMessenger* messenger_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_NOTIFICATION_HANDLER_H_

