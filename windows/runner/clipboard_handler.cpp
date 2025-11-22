#include "clipboard_handler.h"

#include <windows.h>
#include <shlobj.h>
#include <shellapi.h>
#include <comdef.h>
#include <gdiplus.h>
#include <sstream>
#include <vector>
#include <string>
#include <wincrypt.h>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "crypt32.lib")

using namespace Gdiplus;

// Global variables for GDI+ initialization (initialize only once)
static ULONG_PTR gdiplusToken = 0;
static bool gdiplusInitialized = false;

ClipboardHandler::ClipboardHandler(flutter::BinaryMessenger* messenger)
    : messenger_(messenger) {
  // Initialize GDI+ (only once)
  if (!gdiplusInitialized) {
    GdiplusStartupInput gdiplusStartupInput;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
    gdiplusInitialized = true;
  }

  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          messenger_, "com.dora/clipboard",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        this->HandleMethodCall(call, std::move(result));
      });

  channel_ = std::move(channel);
}

ClipboardHandler::~ClipboardHandler() {
  // GDI+ is a global variable, so don't shutdown here
  // It will be automatically shutdown when the app exits
}

void ClipboardHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getClipboardImage") == 0) {
    std::string imageData = GetClipboardImage();
    if (!imageData.empty()) {
      flutter::EncodableMap response = {
          {flutter::EncodableValue("type"), flutter::EncodableValue("base64")},
          {flutter::EncodableValue("data"), flutter::EncodableValue(imageData)}};
      result->Success(response);
      return;
    }

    auto paths = GetClipboardImagePaths();
    if (!paths.empty()) {
      flutter::EncodableList list;
      for (const auto& path : paths) {
        list.emplace_back(flutter::EncodableValue(path));
      }
      flutter::EncodableMap response = {
          {flutter::EncodableValue("type"), flutter::EncodableValue("paths")},
          {flutter::EncodableValue("data"), list}};
      result->Success(response);
      return;
    }

    flutter::EncodableMap response = {
        {flutter::EncodableValue("type"), flutter::EncodableValue("none")}};
    result->Success(response);
  } else {
    result->NotImplemented();
  }
}

std::string ClipboardHandler::GetClipboardImage() {
  if (!OpenClipboard(NULL)) {
    return "";
  }

  std::string result = "";

  // Check for CF_DIB format
  if (IsClipboardFormatAvailable(CF_DIB)) {
    HANDLE hData = GetClipboardData(CF_DIB);
    if (hData != NULL) {
      void* pDibData = GlobalLock(hData);
      if (pDibData != NULL) {
        // Convert image to PNG using IStream
        IStream* pStream = NULL;
        if (CreateStreamOnHGlobal(NULL, TRUE, &pStream) == S_OK) {
          // Convert DIB to GDI+ Bitmap
          Bitmap* pBitmap = new Bitmap((BITMAPINFO*)pDibData, pDibData);
          if (pBitmap != NULL && pBitmap->GetLastStatus() == Ok) {
            // Save as PNG
            CLSID clsidPng;
            CLSIDFromString(L"{557CF406-1A04-11D3-9A73-0000F81EF32E}", &clsidPng);
            
            if (pBitmap->Save(pStream, &clsidPng, NULL) == Ok) {
              // Read data from stream
              STATSTG stat;
              if (pStream->Stat(&stat, STATFLAG_NONAME) == S_OK) {
                ULARGE_INTEGER pos;
                pos.QuadPart = 0;
                pStream->Seek(*(LARGE_INTEGER*)&pos, STREAM_SEEK_SET, NULL);

                std::vector<BYTE> buffer(stat.cbSize.LowPart);
                ULONG bytesRead = 0;
                if (pStream->Read(buffer.data(), stat.cbSize.LowPart, &bytesRead) == S_OK) {
                  // Base64 encoding
                  DWORD base64Len = 0;
                  CryptBinaryToStringA(buffer.data(), bytesRead,
                                      CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                                      NULL, &base64Len);
                  std::vector<CHAR> base64Buffer(base64Len);
                  if (CryptBinaryToStringA(buffer.data(), bytesRead,
                                          CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                                          base64Buffer.data(), &base64Len)) {
                    result = std::string(base64Buffer.data(), base64Len);
                  }
                }
              }
            }
            delete pBitmap;
          }
          pStream->Release();
        }
        GlobalUnlock(hData);
      }
    }
  }

  CloseClipboard();
  return result;
}

std::vector<std::string> ClipboardHandler::GetClipboardImagePaths() {
  std::vector<std::string> paths;
  if (!OpenClipboard(NULL)) {
    return paths;
  }

  if (IsClipboardFormatAvailable(CF_HDROP)) {
    HANDLE hDrop = GetClipboardData(CF_HDROP);
    if (hDrop != NULL) {
      HDROP drop = static_cast<HDROP>(hDrop);
      UINT fileCount = DragQueryFileW(drop, 0xFFFFFFFF, nullptr, 0);
      for (UINT i = 0; i < fileCount; ++i) {
        UINT length = DragQueryFileW(drop, i, nullptr, 0);
        if (length == 0) {
          continue;
        }
        std::wstring buffer(length + 1, L'\0');
        DragQueryFileW(drop, i, buffer.data(), length + 1);
        buffer.resize(length);
        paths.emplace_back(WideStringToUtf8(buffer));
      }
    }
  }

  CloseClipboard();
  return paths;
}

std::string ClipboardHandler::WideStringToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) {
    return std::string();
  }
  int size = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.length()), nullptr, 0, nullptr, nullptr);
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), static_cast<int>(wstr.length()), result.data(), size, nullptr, nullptr);
  return result;
}

