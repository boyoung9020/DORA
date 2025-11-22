#ifndef RUNNER_CLIPBOARD_HANDLER_H_
#define RUNNER_CLIPBOARD_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/binary_messenger.h>
#include <flutter/standard_method_codec.h>
#include <flutter/encodable_value.h>
#include <memory>
#include <vector>
#include <string>

// Clipboard image handler
class ClipboardHandler {
 public:
  explicit ClipboardHandler(flutter::BinaryMessenger* messenger);
  ~ClipboardHandler();

  // Handle platform channel method calls
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  // Get image from clipboard
  std::string GetClipboardImage();
  std::vector<std::string> GetClipboardImagePaths();
  std::string WideStringToUtf8(const std::wstring& wstr);

  flutter::BinaryMessenger* messenger_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_CLIPBOARD_HANDLER_H_

