import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exam_photo_resizer_screen.dart';
import 'rtps_universal_setup_screen.dart';

class RtpsAutofillScreen extends StatefulWidget {
  final bool isDark;
  const RtpsAutofillScreen({super.key, required this.isDark});

  @override
  State<RtpsAutofillScreen> createState() => _RtpsAutofillScreenState();
}

class _RtpsAutofillScreenState extends State<RtpsAutofillScreen> {
  InAppWebViewController? _webViewController;
  double _loadProgress = 0;
  bool _isAutoFilling = false;
  bool _showOtpBar = false;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic>? _savedProfile;

  // 🔗 Direct Portal Endpoint (Bypasses ServicePlus Mobile App Ad Splash)
  static const String _rtpsHomeUrl =
      'https://serviceonline.bihar.gov.in/serviceonline/citizenRegistration.html#/citizenHome';

  // 🌐 Genuine Windows Desktop Chrome Headers jo NIC Firewall aur Mobile Ad ko bypass karte hain
  static const Map<String, String> _browserHeaders = {
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9,hi;q=0.8',
    'Cache-Control': 'max-age=0',
    'Connection': 'keep-alive',
    'Sec-Ch-Ua':
        '"Not-A.Brand";v="99", "Chromium";v="124", "Google Chrome";v="124"',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': '"Windows"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
  };

  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _loadProfileFromStorage();
  }

  Future<void> _loadProfileFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('rtps_universal_profile');
    if (data != null && data.isNotEmpty) {
      try {
        setState(() {
          _savedProfile = jsonDecode(data) as Map<String, dynamic>;
        });
      } catch (e) {
        debugPrint("Error parsing profile: $e");
      }
    }
  }

  void _reloadPage() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(_rtpsHomeUrl),
        headers: _browserHeaders,
      ),
    );
  }

  // 🚀 Fuzzy Cascading Autofill Engine
  Future<void> _triggerSmartAutofill() async {
    if (_webViewController == null) return;

    if (_savedProfile == null) {
      _showProfileMissingSheet();
      return;
    }

    setState(() => _isAutoFilling = true);
    HapticFeedback.heavyImpact();

    final profileJson = jsonEncode(_savedProfile);

    final jsEngine = """
    (async function() {
      const p = $profileJson;
      let filledCount = 0;

      function normalize(str) {
        if (!str) return '';
        return str.toString()
                  .toLowerCase()
                  .replace(/\\(.*?\\)/g, '')
                  .replace(/[\\u0900-\\u097F]/g, '')
                  .replace(/[^a-z0-9]/g, '')
                  .trim();
      }

      function findBestMatchingOption(selectElement, targetText) {
        if (!selectElement || !targetText) return null;
        const targetClean = normalize(targetText);
        if (!targetClean) return null;

        for (let opt of selectElement.options) {
          if (!opt.value || opt.value === '') continue;
          const optTextClean = normalize(opt.text);
          const optValClean = normalize(opt.value);
          if (optTextClean === targetClean || optValClean === targetClean) {
            return opt.value;
          }
        }

        for (let opt of selectElement.options) {
          if (!opt.value || opt.value === '') continue;
          const optTextClean = normalize(opt.text);
          if (optTextClean && (optTextClean.includes(targetClean) || targetClean.includes(optTextClean))) {
            return opt.value;
          }
        }
        return null;
      }

      function setVal(selectors, val) {
        if (!val) return;
        for (let s of selectors) {
          let el = document.querySelector(s);
          if (el) {
            el.value = val;
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            filledCount++;
            break;
          }
        }
      }

      function selectRadio(textPattern) {
        if (!textPattern) return;
        let patternClean = normalize(textPattern);
        let radios = document.querySelectorAll('input[type="radio"]');
        for (let r of radios) {
          let parent = r.closest('label') || r.parentElement;
          if (parent) {
            let labelText = parent.innerText || '';
            if (labelText.toLowerCase().includes(textPattern.toLowerCase()) || normalize(labelText).includes(patternClean)) {
              r.checked = true;
              r.dispatchEvent(new Event('change', { bubbles: true }));
              filledCount++;
              break;
            }
          }
        }
      }

      async function selectDropdownAsync(selectors, targetText, maxWaitMs = 3500) {
        if (!targetText) return false;
        let startTime = Date.now();

        while (Date.now() - startTime < maxWaitMs) {
          for (let s of selectors) {
            let sel = document.querySelector(s);
            if (sel && sel.options && sel.options.length > 1) {
              let matchedValue = findBestMatchingOption(sel, targetText);
              if (matchedValue !== null) {
                sel.value = matchedValue;
                sel.dispatchEvent(new Event('change', { bubbles: true }));
                filledCount++;
                return true;
              }
            }
          }
          await new Promise(r => setTimeout(r, 200));
        }
        return false;
      }

      selectRadio(p.gender === 'FEMALE' ? 'स्त्री' : 'पुरुष');

      setVal(['input[id*="applicant_name"]', 'input[name*="applicant_name"]'], p.name_en);
      setVal(['input[id*="applicant_name_hindi"]', 'input[name*="applicant_name_hindi"]'], p.name_hi);
      setVal(['input[id*="father_name"]', 'input[name*="father_name"]'], p.father_en);
      setVal(['input[id*="father_name_hindi"]', 'input[name*="father_name_hindi"]'], p.father_hi);
      setVal(['input[id*="mother_name"]', 'input[name*="mother_name"]'], p.mother_en);
      setVal(['input[id*="mother_name_hindi"]', 'input[name*="mother_name_hindi"]'], p.mother_hi);

      if (p.husband_en && p.husband_en.length > 0) {
        setVal(['input[id*="husband_name"]', 'input[name*="husband_name"]'], p.husband_en);
        setVal(['input[id*="husband_name_hindi"]', 'input[name*="husband_name_hindi"]'], p.husband_hi);
      }

      setVal(['input[id*="mobile"]', 'input[name*="mobile"]', 'input[type="tel"]'], p.mobile);
      setVal(['input[id*="email"]', 'input[name*="email"]'], p.email);

      setVal(['input[id*="ward_no"]', 'input[name*="ward_no"]', 'input[id*="ward_number"]'], p.ward_no);
      setVal(['input[id*="village"]', 'input[name*="village"]'], p.village);
      setVal(['input[id*="post_office"]', 'input[name*="post_office"]'], p.post_office);
      setVal(['input[id*="pin_code"]', 'input[name*="pin_code"]', 'input[id*="pin"]'], p.pin_code);

      selectRadio(p.local_body_type);
      selectRadio(p.residence_type);

      let sameAsAbove = document.querySelector('input[type="checkbox"][id*="same"], input[type="checkbox"][name*="same"]');
      if (sameAsAbove && !sameAsAbove.checked) {
        sameAsAbove.checked = true;
        sameAsAbove.dispatchEvent(new Event('change', { bubbles: true }));
      }

      setVal(['input[id*="purpose"]', 'input[name*="purpose"]'], p.purpose);
      await selectDropdownAsync(['select[id*="profession"]', 'select[name*="profession"]'], p.profession, 1200);

      setVal(['input[id*="income_govt"]', 'input[name*="income_govt"]', 'input[id*="txt_govt_income"]'], p.income_govt);
      setVal(['input[id*="income_agri"]', 'input[name*="income_agri"]', 'input[id*="txt_agri_income"]'], p.income_agri);
      setVal(['input[id*="income_biz"]', 'input[name*="income_biz"]', 'input[id*="txt_business_income"]'], p.income_biz);
      setVal(['input[id*="income_other"]', 'input[name*="income_other"]', 'input[id*="txt_other_income"]'], p.income_other);
      setVal(['input[id*="total_income"]', 'input[name*="total_income"]', 'input[id*="txt_total_income"]'], p.income_total);

      if (p.caste_category) {
        await selectDropdownAsync(['select[id*="category"]', 'select[name*="category"]'], p.caste_category, 1500);
        if (p.caste_name) {
          await selectDropdownAsync(['select[id*="caste"]', 'select[name*="caste"]'], p.caste_name, 2500);
        }
      }

      let agreeChk = document.querySelector('input[type="checkbox"][id*="agree"], input[type="checkbox"][name*="agree"]');
      if (agreeChk && !agreeChk.checked) {
        agreeChk.checked = true;
        agreeChk.dispatchEvent(new Event('change', { bubbles: true }));
      }

      await selectDropdownAsync(['select[id*="state"]', 'select[name*="state"]'], 'BIHAR', 2000);
      let districtDone = await selectDropdownAsync(['select[id*="district"]', 'select[name*="district"]'], p.district, 3500);

      if (districtDone) {
        let subDivDone = await selectDropdownAsync(['select[id*="sub_division"]', 'select[name*="sub_division"]'], p.sub_division, 3500);
        if (subDivDone) {
          await selectDropdownAsync(['select[id*="block"]', 'select[name*="block"]'], p.block, 3000);
          await selectDropdownAsync(['select[id*="police_station"]', 'select[name*="police_station"]'], p.police_station, 2000);
        }
      }

      setVal(['input[id*="police_station"]', 'input[name*="police_station"]', 'input[id*="thana"]'], p.police_station);

      let photoInput = document.querySelector('input[type="file"]');
      let captchaInput = document.querySelector('input[name*="captcha"], input[id*="captcha"], input[id*="txt_verification"], input[placeholder*="verification"]');

      if (photoInput) {
        photoInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
        photoInput.style.outline = '3px solid #16A34A';
        photoInput.style.padding = '8px';
        photoInput.style.borderRadius = '8px';
      } else if (captchaInput) {
        captchaInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
        captchaInput.style.outline = '3px solid #B45309';
      }

      return { status: 'success', count: filledCount };
    })();
    """;

    try {
      await _webViewController!.evaluateJavascript(source: jsEngine);
      if (mounted) {
        setState(() => _showOtpBar = true);
        _showSuccessGuidanceSheet();
      }
    } catch (e) {
      debugPrint("Autofill Error: $e");
    } finally {
      if (mounted) setState(() => _isAutoFilling = false);
    }
  }

  Future<void> _injectClipboardOtp() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text ?? '';

    final match = RegExp(r'\b\d{6}\b').firstMatch(text);
    if (match != null && _webViewController != null) {
      final otp = match.group(0);

      final jsOtp = """
        (function() {
          let otpBoxes = document.querySelectorAll('input[id*="otp"], input[name*="otp"], input[placeholder*="OTP"], input[id*="txt_otp"]');
          for (let box of otpBoxes) {
            box.value = '$otp';
            box.dispatchEvent(new Event('input', { bubbles: true }));
            box.dispatchEvent(new Event('change', { bubbles: true }));
            box.style.outline = '3px solid #16A34A';
            return true;
          }
          return false;
        })();
      """;

      await _webViewController!.evaluateJavascript(source: jsOtp);
      HapticFeedback.mediumImpact();
      _showToast('✅ OTP "$otp" auto-fill ho gaya! "Validate" dabayein.');
    } else {
      _showToast('⚠️ Clipboard me 6-digit OTP nahi mila. SMS se Copy karein.');
    }
  }

  void _showSuccessGuidanceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF16A34A), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('Form Auto-Filled! ⚡',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Aakhiri steps:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildStepRow('1', 'Photo Upload:',
                  'Green box par tap karke photo chunein (< 50 KB).'),
              const SizedBox(height: 6),
              _buildStepRow('2', 'Captcha & Submit:',
                  'Verification code daal kar Submit dabayein.'),
              const SizedBox(height: 6),
              _buildStepRow(
                  '3', 'OTP Validation:', 'SMS aate hi niche "Paste OTP" dabayein.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ExamPhotoResizerScreen(isDark: widget.isDark),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB45309),
                        side: const BorderSide(color: Color(0xFFB45309)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.photo_size_select_large_rounded,
                          size: 16),
                      label: const Text('Resize Photo',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Samajh Gaya 👍',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: const Color(0xFFB45309),
          child: Text(num,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 11.5,
                  color: widget.isDark ? Colors.white70 : Colors.black87),
              children: [
                TextSpan(
                    text: '$title ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showProfileMissingSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle_outlined,
                  size: 44, color: Color(0xFFB45309)),
              const SizedBox(height: 10),
              const Text('Master Profile Setup Nahi Hai',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              const Text(
                'AutoFill ke liye pehle apni details 1-baar save karein.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            RtpsUniversalSetupScreen(isDark: widget.isDark)),
                  );
                  if (updated == true) _loadProfileFromStorage();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Setup Profile Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Exit RTPS Form?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            content: const Text(
              'Agar aap bahar jayenge to session invalidate ho sakta hai.',
              style: TextStyle(fontSize: 12.5),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Nahi')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Haan, Exit'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('RTPS FastFill Assistant',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              Text('Jati • Aay • Niwas (Zero Timeout)',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note_rounded,
                  color: Color(0xFFB45309)),
              tooltip: 'Edit Profile',
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          RtpsUniversalSetupScreen(isDark: isDark)),
                );
                if (updated == true) _loadProfileFromStorage();
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reloadPage,
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (_loadProgress < 1.0 && !_hasError)
                  LinearProgressIndicator(
                    value: _loadProgress,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFB45309)),
                    minHeight: 3,
                  ),
                Expanded(
                  child: _hasError
                      ? _buildErrorView()
                      : InAppWebView(
                          initialUrlRequest: URLRequest(
                            url: WebUri(_rtpsHomeUrl),
                            headers: _browserHeaders,
                          ),
                          initialSettings: InAppWebViewSettings(
                            userAgent: _desktopUserAgent,
                            useShouldOverrideUrlLoading: true,
                            mediaPlaybackRequiresUserGesture: false,
                            javaScriptEnabled: true,
                            cacheEnabled: true,
                            supportZoom: true,
                            builtInZoomControls: true,
                            displayZoomControls: false,
                            // 🖥️ Desktop Canvas & Mode to kill mobile app banner
                            useWideViewPort: true,
                            loadWithOverviewMode: true,
                            preferredContentMode: UserPreferredContentMode.DESKTOP,
                            mixedContentMode:
                                MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                            domStorageEnabled: true,
                            databaseEnabled: true,
                            thirdPartyCookiesEnabled: true,
                            allowFileAccess: true,
                            allowContentAccess: true,
                            transparentBackground: false,
                          ),
                          onWebViewCreated: (ctrl) =>
                              _webViewController = ctrl,
                          onReceivedServerTrustAuthRequest:
                              (controller, challenge) async {
                            return ServerTrustAuthResponse(
                                action:
                                    ServerTrustAuthResponseAction.PROCEED);
                          },
                          onLoadError: (ctrl, url, code, message) {
                            debugPrint("WebView Load Error: $code | $message");
                            if (mounted) {
                              setState(() {
                                _hasError = true;
                                _errorMessage = message;
                              });
                            }
                          },
                          onLoadHttpError:
                              (ctrl, url, statusCode, description) {
                            debugPrint(
                                "HTTP Error: $statusCode | $description");
                          },
                          onLoadStop: (ctrl, url) async {
                            setState(() {
                              _hasError = false;
                            });

                            // ⚡ Desktop Viewport setup + Interstitial App Banner Remover
                            await ctrl.evaluateJavascript(source: """
                              // 1. Remove mobile app banner if present
                              var banners = document.querySelectorAll('.mobile-app-banner, #mobileAppModal, .app-download-section, [class*="download-app"]');
                              banners.forEach(function(b) { b.remove(); });

                              // 2. Desktop viewport scaling
                              var meta = document.querySelector('meta[name="viewport"]');
                              if (!meta) {
                                meta = document.createElement('meta');
                                meta.name = 'viewport';
                                document.getElementsByTagName('head')[0].appendChild(meta);
                              }
                              meta.content = 'width=1280, initial-scale=' + (window.innerWidth / 1280) + ', maximum-scale=3.0, user-scalable=yes';
                            """);
                          },
                          onProgressChanged: (ctrl, prog) {
                            setState(() => _loadProgress = prog / 100);
                          },
                        ),
                ),
                if (_showOtpBar)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: Row(
                      children: [
                        const Icon(Icons.mark_email_read_rounded,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'SMS Copy karke OTP inject karein:',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _injectClipboardOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.paste_rounded, size: 14),
                          label: const Text('Paste OTP',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (_isAutoFilling)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF16A34A)),
                      SizedBox(height: 12),
                      Text(
                        'Fuzzy Matching Cascading Dropdowns...\nState ➔ District ➔ Sub-Div ➔ Block',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: _hasError
            ? null
            : FloatingActionButton.extended(
                onPressed: _isAutoFilling ? null : _triggerSmartAutofill,
                backgroundColor: const Color(0xFF16A34A),
                elevation: 4,
                icon: _isAutoFilling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.flash_on_rounded, color: Colors.white),
                label: Text(
                  _isAutoFilling ? 'Filling Cascades...' : '⚡ AutoFill Form',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3),
                ),
              ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Color(0xFFB45309)),
            ),
            const SizedBox(height: 16),
            const Text(
              'RTPS Portal Server Busy',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bihar NIC server par traffic ya firewall handshake ki wajah se connection drop hua hai. Re-try karein:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _reloadPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB45309),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Dubara Koshish Karein (Retry)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
