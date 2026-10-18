"""Offline/static support checks; these do not simulate private WeChat APIs."""
import hashlib
from pathlib import Path
import plistlib
import unittest

SETTINGS = Path(__file__).resolve().parents[1]
PROJECT = SETTINGS.parent
RESOURCES = SETTINGS / "Resources"


def plist(path):
    with path.open("rb") as handle:
        return plistlib.load(handle)


class SupportTests(unittest.TestCase):
    def test_resource_plists(self):
        for path in RESOURCES.glob("*.plist"):
            with self.subTest(path=path.name):
                self.assertIsInstance(plist(path), dict)

    def test_existing_preferences_preserved(self):
        items = plist(RESOURCES / "ShortLook.plist")["items"]
        settings = [item for item in items if "key" in item]
        expected = [("Enabled", True), ("LoadContactPhotos", True),
                    ("TranslucentBG", True), ("ShowNotificationBody", False),
                    ("WaitDuration", 1.0), ("DismissOnRaiseToWake", True), ("SleepAfter", False)]
        self.assertEqual([(item["key"], item["default"]) for item in settings], expected)
        for item in settings:
            self.assertEqual(item["defaults"], "co.dynastic.ios.tweak.shortlook")
            self.assertEqual(item["PostNotification"], "co.dynastic.ios.tweak.shortlook.changed")

    def test_support_link(self):
        items = plist(RESOURCES / "ShortLook.plist")["items"]
        entry = items[-1]
        self.assertEqual(entry["id"], "ShortLookSupport")
        self.assertEqual(entry["detail"], "SLDonationController")
        self.assertEqual(entry["cell"], "PSLinkCell")
        self.assertIs(entry["isController"], True)
        self.assertNotIn("DependsOn", entry)
        self.assertNotIn("PostNotification", entry)

    def test_original_principal_class(self):
        info = plist(RESOURCES / "Info.plist")
        self.assertEqual(info["NSPrincipalClass"], "DDSettingsController")
        self.assertEqual(info["CFBundleIdentifier"], "co.dynastic.ios.tweak.shortlook.settings")

    def test_real_appreciation_asset_unchanged(self):
        image = RESOURCES / plist(RESOURCES / "Support.plist")["WeChatQRCode"]
        self.assertEqual(hashlib.sha256(image.read_bytes()).hexdigest(),
                         "1e7bd3830378d49b22c8023d055b3e54601ec2a7b267eb3f7b4f511ed250fd4a")

    def test_resource_names_are_local(self):
        config = plist(RESOURCES / "Support.plist")
        self.assertEqual(config["RecipientName"], "SHINY")
        for key in ("WeChatQRCode",):
            name = config[key]
            self.assertEqual(Path(name).name, name)
            self.assertNotIn("/", name)
            self.assertNotIn("\\", name)
            self.assertNotIn(":", name)
            self.assertIn(Path(name).suffix.lower(), (".png", ".jpg", ".jpeg"))

    def test_wechat_main_process_only(self):
        entry = plist(PROJECT / "SupportWeChat/ShortLookSupportWeChat.plist")
        self.assertEqual(entry, {"Filter": {"Bundles": ["com.tencent.xin"]}})
        source = (PROJECT / "SupportWeChat/Bridge.m").read_text(encoding="utf-8")
        self.assertIn('bundleIdentifier isEqualToString:@"com.tencent.xin"', source)

    def test_wechat_is_the_only_donation_channel(self):
        config = plist(RESOURCES / "Support.plist")
        self.assertEqual(set(config), {"Message", "RecipientName", "WeChatQRCode"})
        source = (SETTINGS / "SLDonationController.m").read_text(encoding="utf-8").lower()
        self.assertNotIn("alipay", source)
        self.assertNotIn("支付宝", source)
        entry = plist(RESOURCES / "ShortLook.plist")["items"][-1]
        self.assertEqual(entry["label"], "微信赞赏")

    def test_build_wiring(self):
        make = (SETTINGS / "Makefile").read_text(encoding="utf-8")
        self.assertIn("ShortLookSettings.m SLDonationController.m", make)
        self.assertIn("ShortLookSettings_PRIVATE_FRAMEWORKS = Preferences", make)
        self.assertIn("SupportWeChat", (PROJECT / "Makefile").read_text())
        bridge_make = (PROJECT / "SupportWeChat/Makefile").read_text()
        self.assertIn("ARCHS = arm64", bridge_make)
        self.assertIn("Bridge.m SLWeChatSupportController.m", bridge_make)

    def test_request_validation_is_bounded(self):
        source = (PROJECT / "SupportWeChat/Bridge.m").read_text(encoding="utf-8")
        for marker in ("SLDonationTimestampIsFresh", "components.queryItems.count != 3",
                       "initWithUUIDString:", "SLConsumedRequests", "com.apple.Preferences",
                       "SLPendingAttempt++ >= 120", "method_getImplementation(method) == replacement"):
            self.assertIn(marker, source)
        self.assertIn("SLDonationPath", source)
        self.assertIn("if (!SLConsumeURL", source)

    def test_scanner_calls_are_runtime_guarded(self):
        source = (PROJECT / "SupportWeChat/SLWeChatSupportController.m").read_text(encoding="utf-8")
        for marker in ("SLCheckMethod", "initWithCodeType:27 fromScene:2", "SLReadCurrentScanLogic",
                       "self.previousScanLogic", "@catch", "原生赞赏入口接口不匹配"):
            self.assertIn(marker, source)
        self.assertIn("self.scanLogic scannerParams:scannerParams", source)

    def test_no_payment_account_or_message_hooks(self):
        paths = [PROJECT / "SupportWeChat/Bridge.m", PROJECT / "SupportWeChat/SLWeChatSupportController.m"]
        source = "\n".join(p.read_text(encoding="utf-8") for p in paths)
        for forbidden in ("amountBtnClick:", "editMoneyBtnClick", "AsyncOnAddMsg", "CContactMgr",
                          "payOrder:", "OpenRedEnvelopes", "WCPayTouchID", "NSURLSession", "WKWebView"):
            self.assertNotIn(forbidden, source)

    def test_settings_relays_directly_without_qr_ui(self):
        source = (SETTINGS / "SLDonationController.m").read_text(encoding="utf-8")
        self.assertIn("didDispatchAutomatically", source)
        self.assertIn("[self openWeChatAppreciation:nil]", source)
        self.assertIn("components.queryItems", source)
        for forbidden in ("UIImageView", "UIActivityViewController", "previewButton", "shareButton",
                          "shareCode:", "尝试免扫码", "UIImageWriteToSavedPhotosAlbum", "PHPhotoLibrary"):
            self.assertNotIn(forbidden, source)

    def test_bridge_does_not_insert_support_navigation(self):
        source = (PROJECT / "SupportWeChat/Bridge.m").read_text(encoding="utf-8")
        self.assertIn("SLOpenWeChatNativeAppreciation(top)", source)
        for forbidden in ("initWithRootViewController:", "modalPresentationStyle", "SLWeChatSupportController alloc"):
            self.assertNotIn(forbidden, source)

    def test_helper_has_no_visible_qr_or_custom_support_controller(self):
        source = (PROJECT / "SupportWeChat/SLWeChatSupportController.m").read_text(encoding="utf-8")
        self.assertIn("@interface SLNativeAppreciationSession : NSObject", source)
        self.assertIn("[self.scanner scanOnePicture:internalImage]", source)
        for forbidden in ("UIImageView", "UIActivityViewController", "shareCode:", "UINavigationController alloc",
                          "@interface SLWeChatSupportController : UIViewController", "CodeType:19"):
            self.assertNotIn(forbidden, source)
        self.assertNotIn("addSubview:self.imageContext.view", source)
        self.assertNotIn("presentViewController:self.imageContext", source)

    def test_only_native_page_entry_counts_as_entry(self):
        source = (PROJECT / "SupportWeChat/SLWeChatSupportController.m").read_text(encoding="utf-8")
        self.assertIn("WCPayQRCodeRewardPayerDetailViewController", source)
        self.assertIn("if (!self.enteredNativePage && page)", source)
        self.assertIn("self.enteredNativePage = YES", source)
        self.assertIn("self.window.rootViewController", source)
        self.assertNotIn("if (!contextKnown)", source)
        self.assertNotIn("if (!previousKnown)", source)
        self.assertNotIn("请使用兼容方式", source)


if __name__ == "__main__":
    unittest.main()
