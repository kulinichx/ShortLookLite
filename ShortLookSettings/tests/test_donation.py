#!/usr/bin/env python3
"""Offline source/config regression checks, NOT a WeChat device test."""
import hashlib
import pathlib
import plistlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PREFS = ROOT / 'ShortLookSettings'
HELPER = ROOT / 'SupportWeChat'


def source(path):
    text = path.read_text(encoding='utf-8')
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


class NativeDonationTests(unittest.TestCase):
    def test_no_clixml_in_feature_files(self):
        files = list(HELPER.glob('*')) + list((ROOT / 'SupportShared').glob('*'))
        files += [PREFS / 'SLDonationController.m', PREFS / 'Resources/Support.plist']
        for path in files:
            if path.is_file():
                with self.subTest(file=path.name):
                    self.assertNotIn(b'<Objs Version=', path.read_bytes())

    def test_support_plist_parses_and_is_wechat_only(self):
        data = plistlib.loads((PREFS / 'Resources/Support.plist').read_bytes())
        self.assertEqual(set(data), {'Message', 'RecipientName', 'WeChatQRCode'})
        self.assertEqual(data['WeChatQRCode'], 'SupportWeChat.jpg')

    def test_filter_only_wechat(self):
        data = plistlib.loads((HELPER / 'ShortLookSupportWeChat.plist').read_bytes())
        self.assertEqual(data, {'Filter': {'Bundles': ['com.tencent.xin']}})

    def test_own_qr_integrity(self):
        image = PREFS / 'Resources/SupportWeChat.jpg'
        self.assertEqual(hashlib.sha256(image.read_bytes()).hexdigest(),
                         '1e7bd3830378d49b22c8023d055b3e54601ec2a7b267eb3f7b4f511ed250fd4a')

    def test_settings_entry_points_to_transit_controller(self):
        data = plistlib.loads((PREFS / 'Resources/ShortLook.plist').read_bytes())
        entries = data.get('items', data.get('PreferenceSpecifiers', []))
        found = [e for e in entries if e.get('detail') == 'SLDonationController']
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0]['label'], '赞赏支持')
        self.assertIn('SLDonationController.m', (PREFS / 'Makefile').read_text())

    def test_transit_opens_once_after_appearance(self):
        text = source(PREFS / 'SLDonationController.m')
        self.assertIn('- (void)viewDidAppear:', text)
        self.assertIn('if (self.requested) return;', text)
        self.assertIn('self.requested = YES;', text)
        self.assertIn('openURL:components.URL', text)

    def test_no_custom_amount_or_payment_ui(self):
        for path in (PREFS / 'SLDonationController.m', HELPER / 'SLWeChatSupportController.m'):
            text = source(path)
            for forbidden in ('UIButton', 'amount_cents', 'UIImageView', 'UIActivityViewController',
                              'amountBtnClick:', 'sendActionsForControlEvents:', 'objc_msgSend'):
                with self.subTest(path=path.name, token=forbidden):
                    self.assertNotIn(forbidden, text)

    def test_request_v3_consistent(self):
        sender = source(PREFS / 'SLDonationController.m')
        receiver = source(HELPER / 'Bridge.m')
        self.assertIn('queryItemWithName:@"v" value:@"3"', sender)
        self.assertIn('[values[@"v"] isEqualToString:@"3"]', receiver)
        self.assertIn('components.queryItems.count != 3', receiver)
        self.assertIn('@[@"v", @"nonce", @"timestamp"]', receiver)
        for key in ('v', 'nonce', 'timestamp'):
            self.assertIn('queryItemWithName:@"' + key + '"', sender)

    def test_request_rejects_duplicates_and_foreign_sources(self):
        text = source(HELPER / 'Bridge.m')
        self.assertIn('values[item.name]', text)
        self.assertIn('com.apple.Preferences', text)
        self.assertIn('components.fragment', text)
        self.assertIn('components.password', text)
        self.assertIn('components.port', text)

    def test_request_is_fresh_and_one_shot(self):
        text = source(HELPER / 'Bridge.m')
        self.assertIn('SLDonationTimestampIsFresh', text)
        self.assertIn('[SLConsumedRequests containsObject:nonce]', text)
        self.assertIn('[SLConsumedRequests addObject:nonce]', text)
        self.assertIn('SLPendingRequest = nil;', text)

    def test_modern_and_legacy_url_hooks_remain(self):
        text = source(HELPER / 'Bridge.m')
        for selector in ('application:openURL:options:', 'application:openURL:sourceApplication:annotation:',
                         'application:handleOpenURL:', 'scene:openURLContexts:',
                         'scene:willConnectToSession:options:'):
            self.assertIn(selector, text)
        self.assertIn('if (original && remaining.count)', text)

    def test_native_entry_matches_reference_signature_chain(self):
        text = source(HELPER / 'SLWeChatSupportController.m')
        for name in ('MsgImgFullScreenViewController', 'ScanQRCodeLogicParams', 'NewQRCodeScannerParams',
                     'ScanQRCodeLogicController', 'MMServiceCenter', 'ScanQRCodeResultsMgr', 'NewQRCodeScanner'):
            self.assertIn('@"' + name + '"', text)
        self.assertIn('initWithCodeType:27 fromScene:2', text)
        self.assertIn('initWithCodeType:27]', text)
        self.assertIn('scanOnePicture:internalImage', text)
        self.assertIn('SLCheckMethod', text)

    def test_native_page_not_url_acceptance_is_success(self):
        text = source(HELPER / 'SLWeChatSupportController.m')
        self.assertIn('WCPayQRCodeRewardPayerDetailViewController', text)
        self.assertIn('SLFindRewardPage([self applicationRoot])', text)
        self.assertIn('self.enteredNativePage = YES;', text)
        self.assertIn('if (!page) [self finish];', text)

    def test_resources_are_relative_and_not_downloaded(self):
        text = source(HELPER / 'SLWeChatSupportController.m')
        self.assertIn('dladdr(', text)
        self.assertIn('PreferenceBundles/ShortLookSettings.bundle', text)
        for forbidden in ('NSURLSession', 'NSURLConnection', 'http:', 'https:', '/var/jb', '/var/mobile'):
            self.assertNotIn(forbidden, text)

    def test_restore_only_owned_scan_context(self):
        text = source(HELPER / 'SLWeChatSupportController.m')
        self.assertIn('known && current == self.scanLogic', text)
        self.assertIn('[self.watchdog invalidate]', text)
        self.assertIn('[self.imageContext removeFromParentViewController]', text)

    def test_feature_is_bundled_without_springboard_filter(self):
        self.assertIn('SupportWeChat', (ROOT / 'Makefile').read_text())
        self.assertIn('ARCHS = arm64', (HELPER / 'Makefile').read_text())
        self.assertNotIn('SpringBoard', (HELPER / 'ShortLookSupportWeChat.plist').read_text())


if __name__ == '__main__':
    unittest.main(verbosity=2)
