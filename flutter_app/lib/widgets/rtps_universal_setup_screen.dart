import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RtpsUniversalSetupScreen extends StatefulWidget {
  final bool isDark;
  const RtpsUniversalSetupScreen({super.key, required this.isDark});

  @override
  State<RtpsUniversalSetupScreen> createState() => _RtpsUniversalSetupScreenState();
}

class _RtpsUniversalSetupScreenState extends State<RtpsUniversalSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Names (English + Hindi)
  final _nameEn = TextEditingController();
  final _nameHi = TextEditingController();
  final _fatherEn = TextEditingController();
  final _fatherHi = TextEditingController();
  final _motherEn = TextEditingController();
  final _motherHi = TextEditingController();
  final _husbandEn = TextEditingController();
  final _husbandHi = TextEditingController();

  // Contact
  final _mobile = TextEditingController();
  final _email = TextEditingController();

  // Address
  final _wardNo = TextEditingController();
  final _village = TextEditingController();
  final _postOffice = TextEditingController();
  final _pinCode = TextEditingController();

  // Location Dropdowns
  String _selectedDistrict = 'PATNA';
  final _subDivision = TextEditingController();
  final _block = TextEditingController();
  final _policeStation = TextEditingController();

  // Selections
  String _gender = 'MALE';
  String _localBodyType = 'Gram Panchayat';
  String _residenceType = 'स्थायी (Permanent)';
  String _profession = 'छात्र (Student)';
  final _purpose = TextEditingController(text: 'उच्च शिक्षण / सरकारी नौकरी');

  // Income Fields
  final _incomeGovt = TextEditingController(text: '0');
  final _incomeAgri = TextEditingController(text: '0');
  final _incomeBiz = TextEditingController(text: '0');
  final _incomeOther = TextEditingController(text: '90000');
  final _incomeTotal = TextEditingController(text: '90000');

  // Caste Fields
  String _casteCategory = 'अत्यंत पिछड़ा वर्ग (अनुसूची-1) / EBC';
  final _casteName = TextEditingController();

  bool _isLoading = true;

  final List<String> _biharDistricts = [
    'ARARIA', 'ARWAL', 'AURANGABAD', 'BANKA', 'BEGUSARAI', 'BHAGALPUR',
    'BHOJPUR', 'BUXAR', 'DARBHANGA', 'EAST CHAMPARAN (MOTIHARI)', 'GAYA',
    'GOPALGANJ', 'JAMUI', 'JEHANABAD', 'KAIMUR (BHABHUA)', 'KATIHAR',
    'KHAGARIA', 'KISHANGANJ', 'LAKHISARAI', 'MADHEPURA', 'MADHUBANI',
    'MUNGER', 'MUZAFFARPUR', 'NALANDA', 'NAWADA', 'PATNA', 'PURNIA',
    'ROHTAS', 'SAHARSA', 'SAMASTIPUR', 'SARAN', 'SHEIKHPURA', 'SHEOHAR',
    'SITAMARHI', 'SIWAN', 'SUPAUL', 'VAISHALI', 'WEST CHAMPARAN'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('rtps_universal_profile');
    if (raw != null && raw.isNotEmpty) {
      try {
        final d = jsonDecode(raw) as Map<String, dynamic>;
        _nameEn.text = d['name_en'] ?? '';
        _nameHi.text = d['name_hi'] ?? '';
        _fatherEn.text = d['father_en'] ?? '';
        _fatherHi.text = d['father_hi'] ?? '';
        _motherEn.text = d['mother_en'] ?? '';
        _motherHi.text = d['mother_hi'] ?? '';
        _husbandEn.text = d['husband_en'] ?? '';
        _husbandHi.text = d['husband_hi'] ?? '';
        _mobile.text = d['mobile'] ?? '';
        _email.text = d['email'] ?? '';
        _wardNo.text = d['ward_no'] ?? '';
        _village.text = d['village'] ?? '';
        _postOffice.text = d['post_office'] ?? '';
        _pinCode.text = d['pin_code'] ?? '';
        _subDivision.text = d['sub_division'] ?? '';
        _block.text = d['block'] ?? '';
        _policeStation.text = d['police_station'] ?? '';
        _purpose.text = d['purpose'] ?? 'उच्च शिक्षण / सरकारी नौकरी';

        _gender = d['gender'] ?? 'MALE';
        _selectedDistrict = d['district'] ?? 'PATNA';
        _localBodyType = d['local_body_type'] ?? 'Gram Panchayat';
        _residenceType = d['residence_type'] ?? 'स्थायी (Permanent)';
        _profession = d['profession'] ?? 'छात्र (Student)';

        _incomeGovt.text = d['income_govt'] ?? '0';
        _incomeAgri.text = d['income_agri'] ?? '0';
        _incomeBiz.text = d['income_biz'] ?? '0';
        _incomeOther.text = d['income_other'] ?? '90000';
        _incomeTotal.text = d['income_total'] ?? '90000';

        _casteCategory = d['caste_category'] ?? 'अत्यंत पिछड़ा वर्ग (अनुसूची-1) / EBC';
        _casteName.text = d['caste_name'] ?? '';
      } catch (e) {
        debugPrint("Error loading profile: $e");
      }
    }
    setState(() => _isLoading = false);
  }

  void _calculateTotalIncome() {
    final g = int.tryParse(_incomeGovt.text.trim()) ?? 0;
    final a = int.tryParse(_incomeAgri.text.trim()) ?? 0;
    final b = int.tryParse(_incomeBiz.text.trim()) ?? 0;
    final o = int.tryParse(_incomeOther.text.trim()) ?? 0;
    _incomeTotal.text = (g + a + b + o).toString();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kripya zaroori fields sahi se bharein!')),
      );
      return;
    }

    _calculateTotalIncome();

    final profile = {
      'name_en': _nameEn.text.trim(),
      'name_hi': _nameHi.text.trim(),
      'father_en': _fatherEn.text.trim(),
      'father_hi': _fatherHi.text.trim(),
      'mother_en': _motherEn.text.trim(),
      'mother_hi': _motherHi.text.trim(),
      'husband_en': _husbandEn.text.trim(),
      'husband_hi': _husbandHi.text.trim(),
      'mobile': _mobile.text.trim(),
      'email': _email.text.trim(),
      'district': _selectedDistrict.trim(),
      'sub_division': _subDivision.text.trim(),
      'block': _block.text.trim(),
      'police_station': _policeStation.text.trim(),
      'ward_no': _wardNo.text.trim(),
      'village': _village.text.trim(),
      'post_office': _postOffice.text.trim(),
      'pin_code': _pinCode.text.trim(),
      'gender': _gender,
      'local_body_type': _localBodyType,
      'residence_type': _residenceType,
      'profession': _profession,
      'purpose': _purpose.text.trim(),
      'income_govt': _incomeGovt.text.trim(),
      'income_agri': _incomeAgri.text.trim(),
      'income_biz': _incomeBiz.text.trim(),
      'income_other': _incomeOther.text.trim(),
      'income_total': _incomeTotal.text.trim(),
      'caste_category': _casteCategory,
      'caste_name': _casteName.text.trim(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rtps_universal_profile', jsonEncode(profile));

    HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ RTPS Master Profile Safalta-purvak Save Ho Gayi!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFB45309))),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('RTPS Master Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 14),
            _buildSectionHeader('1. Vyaktigat Vivaran (Personal Info)', Icons.person_rounded),
            _buildCard([
              _buildGenderSelector(),
              const SizedBox(height: 12),
              _buildTextField('Aavedak Ka Naam (English)', _nameEn, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField('आवेदक का नाम (Hindi)', _nameHi, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField("Pita Ka Naam (Father's Name)", _fatherEn, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField("पिता का नाम (Hindi)", _fatherHi, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField("Mata Ka Naam (Mother's Name)", _motherEn, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField("माता का नाम (Hindi)", _motherHi, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField("Pati Ka Naam (Yadi vivahit hain)", _husbandEn),
              const SizedBox(height: 10),
              _buildTextField("पति का नाम (Hindi)", _husbandHi),
            ], cardBg),
            const SizedBox(height: 16),
            _buildSectionHeader('2. Sampark & Sthan (Contact & Location)', Icons.location_on_rounded),
            _buildCard([
              _buildTextField('Mobile No (OTP aayega)', _mobile, isRequired: true, keyboard: TextInputType.phone),
              const SizedBox(height: 10),
              _buildTextField('Email Address', _email, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildDistrictDropdown(),
              const SizedBox(height: 10),
              _buildTextField('Anumandal (Sub-Division) jaise: Patna Sadar', _subDivision, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField('Prakhand (Block) jaise: Sampatchak', _block, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField('Thana (Police Station)', _policeStation, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField('Ward No', _wardNo, keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _buildTextField('Gaon / Mohalla (Village / Town)', _village, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField('Dakghar (Post Office)', _postOffice, isRequired: true),
              const SizedBox(height: 10),
              _buildTextField('Pin Code', _pinCode, isRequired: true, keyboard: TextInputType.number),
            ], cardBg),
            const SizedBox(height: 16),
            _buildSectionHeader('3. Jati & Pesha (Caste & Profession)', Icons.badge_rounded),
            _buildCard([
              _buildProfessionDropdown(),
              const SizedBox(height: 10),
              _buildTextField('Aavedan Ka Uddeshya (Purpose)', _purpose),
              const SizedBox(height: 10),
              _buildCasteCategoryDropdown(),
              const SizedBox(height: 10),
              _buildTextField('Jati Ka Naam (Caste) jaise: Kushwaha / Yadav', _casteName, isRequired: true),
            ], cardBg),
            const SizedBox(height: 16),
            _buildSectionHeader('4. Aay Ka Vivaran (Income Details)', Icons.currency_rupee_rounded),
            _buildCard([
              _buildTextField('Sarkari Seva Se Aay', _incomeGovt, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              const SizedBox(height: 8),
              _buildTextField('Krishi (Agriculture) Se Aay', _incomeAgri, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              const SizedBox(height: 8),
              _buildTextField('Vyavsayik (Business) Aay', _incomeBiz, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              const SizedBox(height: 8),
              _buildTextField('Anya Shroton Se Aay', _incomeOther, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              const SizedBox(height: 10),
              _buildTextField('Kul Varshik Aay (Total Income)', _incomeTotal, isRequired: true, keyboard: TextInputType.number),
            ], cardBg),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: const Text('Master Profile Save Karein ⚡', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Yahan apni details 1-baar bharein. RTPS Jati, Aay, Niwas form kholte hi 1-click me saara form bina session timeout ke fill ho jayega.',
              style: TextStyle(fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFB45309)),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children, Color bg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        const Text('Gender: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        const SizedBox(width: 10),
        ChoiceChip(
          label: const Text('पुरुष (Male)'),
          selected: _gender == 'MALE',
          onSelected: (v) => setState(() => _gender = 'MALE'),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('स्त्री (Female)'),
          selected: _gender == 'FEMALE',
          onSelected: (v) => setState(() => _gender = 'FEMALE'),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isRequired = false, TextInputType keyboard = TextInputType.text, void Function(String)? onChanged}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      onChanged: onChanged,
      validator: (v) {
        if (isRequired && (v == null || v.trim().isEmpty)) {
          return '$label zaroori hai';
        }
        return null;
      },
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedDistrict,
      decoration: InputDecoration(
        labelText: 'Zila (District)',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      items: _biharDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
      onChanged: (v) => setState(() => _selectedDistrict = v ?? 'PATNA'),
    );
  }

  Widget _buildProfessionDropdown() {
    final list = ['छात्र (Student)', 'सरकारी सेवा (Govt Service)', 'निजी सेवा (Private Service)', 'व्यापार (Business)', 'किसान (Farmer)', 'गृहणी (Housewife)', 'अन्य (Other)'];
    return DropdownButtonFormField<String>(
      value: list.contains(_profession) ? _profession : list.first,
      decoration: InputDecoration(
        labelText: 'Pesha (Profession)',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      items: list.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
      onChanged: (v) => setState(() => _profession = v ?? list.first),
    );
  }

  Widget _buildCasteCategoryDropdown() {
    final list = [
      'अत्यंत पिछड़ा वर्ग (अनुसूची-1) / EBC',
      'पिछड़ा वर्ग (अनुसूची-2) / BC',
      'अनुसूचित जाति / SC',
      'अनुसूचित जनजाति / ST',
      'गैर-आरक्षित (General / EWS)'
    ];
    return DropdownButtonFormField<String>(
      value: list.contains(_casteCategory) ? _casteCategory : list.first,
      decoration: InputDecoration(
        labelText: 'Varg (Category)',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      items: list.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
      onChanged: (v) => setState(() => _casteCategory = v ?? list.first),
    );
  }
}
