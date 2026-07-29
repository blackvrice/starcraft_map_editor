#include "flutter_window.h"

#include <commdlg.h>
#include <objbase.h>
#include <shobjidl.h>

#include <optional>
#include <string>
#include <utility>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

std::wstring Utf16FromUtf8String(const std::string& value) {
  if (value.empty()) {
    return {};
  }
  const int length = MultiByteToWideChar(
      CP_UTF8,
      MB_ERR_INVALID_CHARS,
      value.data(),
      static_cast<int>(value.size()),
      nullptr,
      0);
  if (length <= 0) {
    return {};
  }
  std::wstring converted(static_cast<std::size_t>(length), L'\0');
  if (MultiByteToWideChar(
          CP_UTF8,
          MB_ERR_INVALID_CHARS,
          value.data(),
          static_cast<int>(value.size()),
          converted.data(),
          length) != length) {
    return {};
  }
  return converted;
}

enum class DirectoryDialogStatus { accepted, cancelled, failed };

struct DirectoryDialogSelection {
  DirectoryDialogStatus status = DirectoryDialogStatus::failed;
  std::string path;
  HRESULT error = E_FAIL;
};

DirectoryDialogSelection FailedDirectorySelection(HRESULT error) {
  DirectoryDialogSelection selection;
  selection.error = error;
  return selection;
}

DirectoryDialogSelection CancelledDirectorySelection(HRESULT error) {
  DirectoryDialogSelection selection;
  selection.status = DirectoryDialogStatus::cancelled;
  selection.error = error;
  return selection;
}

DirectoryDialogSelection AcceptedDirectorySelection(std::string path) {
  DirectoryDialogSelection selection;
  selection.status = DirectoryDialogStatus::accepted;
  selection.path = std::move(path);
  selection.error = S_OK;
  return selection;
}

class ScopedComInitialization {
 public:
  ScopedComInitialization()
      : result_(CoInitializeEx(
            nullptr,
            COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE)),
        should_uninitialize_(SUCCEEDED(result_)) {}

  ~ScopedComInitialization() {
    if (should_uninitialize_) {
      CoUninitialize();
    }
  }

  HRESULT result() const { return result_; }

 private:
  HRESULT result_;
  bool should_uninitialize_;
};

DirectoryDialogSelection PickStarCraftDataDirectory(HWND owner) {
  ScopedComInitialization com;
  if (FAILED(com.result()) && com.result() != RPC_E_CHANGED_MODE) {
    return FailedDirectorySelection(com.result());
  }

  IFileOpenDialog* dialog = nullptr;
  HRESULT result = CoCreateInstance(
      CLSID_FileOpenDialog,
      nullptr,
      CLSCTX_INPROC_SERVER,
      IID_PPV_ARGS(&dialog));
  if (FAILED(result)) {
    return FailedDirectorySelection(result);
  }

  DWORD options = 0;
  result = dialog->GetOptions(&options);
  if (SUCCEEDED(result)) {
    result = dialog->SetOptions(
        options | FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM |
        FOS_PATHMUSTEXIST | FOS_NOCHANGEDIR);
  }
  if (SUCCEEDED(result)) {
    result = dialog->SetTitle(L"Choose StarCraft Data Asset Directory");
  }
  if (SUCCEEDED(result)) {
    result = dialog->Show(owner);
  }
  if (result == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
    dialog->Release();
    return CancelledDirectorySelection(result);
  }
  if (FAILED(result)) {
    dialog->Release();
    return FailedDirectorySelection(result);
  }

  IShellItem* selected_item = nullptr;
  result = dialog->GetResult(&selected_item);
  dialog->Release();
  if (FAILED(result)) {
    return FailedDirectorySelection(result);
  }

  PWSTR selected_path = nullptr;
  result = selected_item->GetDisplayName(SIGDN_FILESYSPATH, &selected_path);
  selected_item->Release();
  if (FAILED(result)) {
    return FailedDirectorySelection(result);
  }

  const std::string path = Utf8FromUtf16(selected_path);
  CoTaskMemFree(selected_path);
  if (path.empty()) {
    return FailedDirectorySelection(E_INVALIDARG);
  }
  return AcceptedDirectorySelection(path);
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
  RegisterPlugins(flutter_controller_->engine());
  file_dialog_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "starcraft_map_editor/file_dialog",
          &flutter::StandardMethodCodec::GetInstance());
  file_dialog_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const bool is_open = call.method_name() == "openMap";
        const bool is_save = call.method_name() == "saveMap";
        const bool is_data_directory =
            call.method_name() == "pickStarCraftDataDirectory";
        if (!is_open && !is_save && !is_data_directory) {
          result->NotImplemented();
          return;
        }

        if (is_data_directory) {
          const DirectoryDialogSelection selection =
              PickStarCraftDataDirectory(GetHandle());
          if (selection.status == DirectoryDialogStatus::accepted) {
            result->Success(flutter::EncodableValue(selection.path));
            return;
          }
          if (selection.status == DirectoryDialogStatus::cancelled) {
            result->Success();
            return;
          }
          result->Error(
              "DIRECTORY_DIALOG_FAILED",
              "The Windows directory dialog could not be opened.",
              flutter::EncodableValue(
                  static_cast<int64_t>(selection.error)));
          return;
        }

        wchar_t selected_path[32768] = {};
        if (is_save) {
          const auto* arguments =
              std::get_if<flutter::EncodableMap>(call.arguments());
          if (arguments != nullptr) {
            const auto iterator = arguments->find(
                flutter::EncodableValue("suggestedName"));
            if (iterator != arguments->end()) {
              const auto* suggested_name =
                  std::get_if<std::string>(&iterator->second);
              if (suggested_name != nullptr) {
                const auto converted =
                    Utf16FromUtf8String(*suggested_name);
                wcsncpy_s(
                    selected_path,
                    converted.c_str(),
                    _TRUNCATE);
              }
            }
          }
        }
        constexpr wchar_t filter[] =
            L"StarCraft maps (*.scm;*.scx)\0*.scm;*.scx\0"
            L"All files (*.*)\0*.*\0";
        OPENFILENAMEW dialog = {};
        dialog.lStructSize = sizeof(dialog);
        dialog.hwndOwner = GetHandle();
        dialog.lpstrFile = selected_path;
        dialog.nMaxFile =
            static_cast<DWORD>(sizeof(selected_path) / sizeof(wchar_t));
        dialog.lpstrFilter = filter;
        dialog.nFilterIndex = 1;
        dialog.lpstrTitle =
            is_open ? L"Open StarCraft Map" : L"Save StarCraft Map As";
        dialog.lpstrDefExt = L"scx";
        dialog.Flags =
            OFN_EXPLORER | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;
        if (is_open) {
          dialog.Flags |= OFN_FILEMUSTEXIST;
        } else {
          dialog.Flags |= OFN_OVERWRITEPROMPT;
        }

        const BOOL accepted = is_open
                                  ? ::GetOpenFileNameW(&dialog)
                                  : ::GetSaveFileNameW(&dialog);
        if (accepted) {
          result->Success(flutter::EncodableValue(Utf8FromUtf16(selected_path)));
          return;
        }

        const DWORD error = ::CommDlgExtendedError();
        if (error == 0) {
          result->Success();
          return;
        }

        result->Error("FILE_DIALOG_FAILED",
                      "The Windows file dialog could not be opened.",
                      flutter::EncodableValue(static_cast<int64_t>(error)));
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
  file_dialog_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

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
