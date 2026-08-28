import Foundation

enum L10n {
    private static func s(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static var scan: String { s("scan") }
    static var make: String { s("make") }
    static var clear: String { s("clear") }
    static var copy: String { s("copy") }
    static var gallery: String { s("gallery") }
    static var save: String { s("save") }
    static var ok: String { s("ok") }
    static var cancel: String { s("cancel") }
    static var returnText: String { s("return_text") }
    static var done: String { s("done") }

    static var menuQrCode: String { s("menu_qr_code") }
    static var qrCode: String { s("qr_code") }
    static var scanQrCode: String { s("scan_qr_code") }
    static var makeQrCode: String { s("make_qr_code") }
    static var errorCreatingQR: String { s("error_creating_qr") }
    static var errorSavingQR: String { s("error_saving_qr") }
    static var qrSavedCountFormat: String { s("qr_saved_count") }

    static var cannotOpenImage: String { s("cannot_open_image") }
    static var cannotDecodeImage: String { s("cannot_decode_image") }
    static var retryAfterAuthorization: String { s("retry_after_authorization") }
    static var cameraNotFound: String { s("camera_not_found") }
    static var cameraSessionSetupFailed: String { s("camera_session_setup_failed") }

    static var permissionCameraRationale: String { s("permission_camera_rationale") }

    static var copiedToClipboard: String { s("copied_to_clipboard") }
    static var openSystemSettings: String { s("open_system_settings") }
    static var doAffair: String { s("do_affair") }
}
