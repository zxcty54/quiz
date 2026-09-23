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
  final _policeStation = TextEditingController();

  // Cascading Hierarchy (District -> Sub-Division -> Block)
  String _selectedDistrict = 'PATNA';
  String? _selectedSubDiv;
  String? _selectedBlock;

  // Selections
  String _gender = 'MALE';
  String _localBodyType = 'Gram Panchayat (ग्राम पंचायत)';
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

  // 🏛️ Official Bihar RTPS Administrative Hierarchy (District -> Sub-Divisions -> Blocks)
  static const Map<String, Map<String, List<String>>> _biharAdminData = {
    'PATNA': {
      'Patna Sadar': ['Patna Sadar', 'Phulwari Sharif', 'Sampatchak', 'Fatwah', 'Daniyawan', 'Khusrupur'],
      'Danapur': ['Danapur', 'Maner', 'Bihta'],
      'Barh': ['Barh', 'Bakhtiarpur', 'Mokama', 'Belchhi', 'Ghoswari', 'Pandarak'],
      'Masaurhi': ['Masaurhi', 'Dhanarua', 'Punpun'],
      'Paliganj': ['Paliganj', 'Dulhin Bazar', 'Bikram'],
      'Patna City': ['Patna City'],
    },
    'GAYA': {
      'Gaya Sadar': ['Gaya Town', 'Bodhgaya', 'Manpur', 'Barachatti', 'Fatehpur', 'Mohanpur', 'Paraiya', 'Tan Kuppa', 'Wazirganj'],
      'Tekari': ['Tekari', 'Konch', 'Belaganj'],
      'Sherghati': ['Sherghati', 'Amas', 'Bankey Bazar', 'Dobhi', 'Dumaria', 'Gurua', 'Imamganj'],
      'Neemchak Bathani': ['Bathani', 'Atri', 'Khizirsarai', 'Mohra'],
    },
    'MUZAFFARPUR': {
      'Muzaffarpur East': ['Mushahari', 'Bochahan', 'Gaighat', 'Aurai', 'Katra', 'Minapur', 'Muraul', 'Sakra', 'Bandra'],
      'Muzaffarpur West': ['Kanti', 'Motipur', 'Baruraj', 'Paroo', 'Sahebganj', 'Saraiya', 'Marwan'],
    },
    'BHAGALPUR': {
      'Bhagalpur Sadar': ['Jagdishpur', 'Nathnagar', 'Sultanganj', 'Sabour', 'Goradih', 'Shahkund'],
      'Kahalgaon': ['Kahalgaon', 'Pirpainti', 'Sanokhar'],
      'Naugachhia': ['Naugachhia', 'Gopalpur', 'Ismailpur', 'Bihpur', 'Kharik', 'Narayanpur', 'Rangra Chowk'],
    },
    'NALANDA': {
      'Bihar Sharif': ['Bihar Sharif', 'Rahui', 'Noorsarai', 'Harnaut', 'Chandi', 'Giriak', 'Asthawan', 'Sarmera', 'Bind'],
      'Rajgir': ['Rajgir', 'Silao', 'Islampur', 'Ben', 'Katrisarai'],
      'Hilsa': ['Hilsa', 'Ekangarsarai', 'Karai Parsurai', 'Nagar Nausa', 'Parwalpur', 'Tharthari'],
    },
    'BHOJPUR': {
      'Arrah Sadar': ['Arrah', 'Barhara', 'Koilwar', 'Udwantnagar', 'Sandesh', 'Shahpur'],
      'Jagdishpur': ['Jagdishpur', 'Bihiya', 'Piro'],
      'Piro': ['Tarari', 'Charpokhari', 'Garhani', 'Agiaon'],
    },
    'DARBHANGA': {
      'Darbhanga Sadar': ['Darbhanga', 'Bahadurpur', 'Hayaghat', 'Hanumannagar', 'Keoti', 'Jale', 'Singhwara', 'Manigachhi'],
      'Benipur': ['Benipur', 'Alinagar', 'Baheri'],
      'Biraul': ['Biraul', 'Ghanshyampur', 'Kusheshwar Asthan', 'Kusheshwar Asthan East', 'Kiratpur', 'Gora Bauram'],
    },
    'PURNEA': {
      'Purnia Sadar': ['Purnia East', 'Kasba', 'Jalalgarh', 'Krinayanand Nagar'],
      'Dhamdaha': ['Dhamdaha', 'Banmankhi', 'Bhawanipur', 'Rupauli'],
      'Baisi': ['Baisi', 'Amour', 'Baisa', 'Dagarua'],
      'Banmankhi': ['Banmankhi'],
    },
    'ROHTAS': {
      'Sasaram': ['Sasaram', 'Sheosagar', 'Chenari', 'Kargahar', 'Nokha', 'Tilouthu', 'Akorhigola', 'Rohtas'],
      'Bikramganj': ['Bikramganj', 'Karakot', 'Dinara', 'Dawath', 'Surajpura', 'Sanjhauli'],
      'Dehri': ['Dehri', 'Nasriganj', 'Nauhatta', 'Rajpur'],
    },
    'SARAN': {
      'Chhapra': ['Chhapra', 'Revelganj', 'Garkha', 'Jalalpur', 'Manjhi', 'Nagra', 'Rivilganj', 'Ekma', 'Baniapur'],
      'Marhaura': ['Marhaura', 'Amnour', 'Taraiya', 'Mashrakh', 'Panapur', 'Isuapur'],
      'Sonepur': ['Sonepur', 'Dighwara', 'Dariyapur', 'Parsa', 'Maker'],
    },
    'VAISHALI': {
      'Hajipur': ['Hajipur', 'Bidupur', 'Lalganj', 'Bhagwanpur', 'Vaishali'],
      'Mahnar': ['Mahnar', 'Sahdai Buzurg', 'Desri'],
      'Mahua': ['Mahua', 'Jandaha', 'Patepur', 'Chehrakalan', 'Patedhi Belsar', 'Raghopur', 'Raja Pakar'],
    },
    'SAMASTIPUR': {
      'Samastipur Sadar': ['Samastipur', 'Kalyanpur', 'Warisnagar', 'Khanpur', 'Pusa', 'Tajpur', 'Morbawa'],
      'Dalsinghsarai': ['Dalsinghsarai', 'Ujiarpur', 'Bibhutipur'],
      'Rosera': ['Rosera', 'Hasanpur', 'Singhia', 'Shivaji Nagar'],
      'Patori': ['Patori', 'Mohiuddin Nagar', 'Mohanpur'],
    },
    'BEGUSARAI': {
      'Begusarai Sadar': ['Begusarai', 'Barauni', 'Matihani', 'Shamho Akha Kurha'],
      'Bakhri': ['Bakhri', 'Garhpura', 'Naokothi'],
      'Ballia': ['Ballia', 'Sahebpur Kamal', 'Dandari'],
      'Manjhaul': ['Cheria Bariarpur', 'Chhorahi'],
      'Teghra': ['Teghra', 'Bachhwara', 'Bhagwanpur', 'Mansurchak'],
    },
    'EAST CHAMPARAN (MOTIHARI)': {
      'Motihari Sadar': ['Motihari', 'Turkaulia', 'Piprakothi', 'Kotwa', 'Sugauli', 'Banjaria', 'Harsidhi'],
      'Areraj': ['Areraj', 'Paharpur', 'Sangrampur'],
      'Raxaul': ['Raxaul', 'Adapur', 'Ramgarhwa'],
      'Sikrahna': ['Dhaka', 'Chiraiya', 'Ghorasahan', 'Bankaura'],
      'Pakridayal': ['Pakridayal', 'Madhuban', 'Phenhara', 'Tetaria', 'Patahi'],
      'Chakia (Mehsi)': ['Chakia', 'Mehsi', 'Kalyanpur', 'Kesaria'],
    },
    'WEST CHAMPARAN': {
      'Bettiah Sadar': ['Bettiah', 'Bairia', 'Majhaulia', 'Chanpatia', 'Nautan'],
      'Bagaha': ['Bagaha 1', 'Bagaha 2', 'Ramnagar', 'Thakaraha', 'Bhitaha', 'Piprasi', 'Madhubani'],
      'Narkatiaganj': ['Narkatiaganj', 'Laariya', 'Gaunaha', 'Mainatand', 'Sikta'],
    },
    'SIWAN': {
      'Siwan Sadar': ['Siwan', 'Mairwa', 'Darauli', 'Guthani', 'Hussainganj', 'Andar', 'Ziradei', 'Pachrukhi', 'Barharia', 'Goriyakothi', 'Lakri Nabiganj'],
      'Maharajganj': ['Maharajganj', 'Daraundha', 'Bhagwanpur Hat', 'Basantpur'],
    },
    'GOPALGANJ': {
      'Gopalganj Sadar': ['Gopalganj', 'Manjha', 'Thawe', 'Kuchaikote', 'Barauli', 'Sidhwalia', 'Baikunthpur'],
      'Hathua': ['Hathua', 'Uchkagaon', 'Mirganj', 'Bhorey', 'Kateya', 'Bijaipur', 'Pachdeuri'],
    },
    'MADHUBANI': {
      'Madhubani Sadar': ['Rajnagar', 'Pandaul', 'Kaluahi', 'Bisfi'],
      'Jainagar': ['Jainagar', 'Ladania', 'Basopatti'],
      'Benipatti': ['Benipatti', 'Madhwapur', 'Harlakhi'],
      'Jhanjharpur': ['Jhanjharpur', 'Lakhnaur', 'Madhepur', 'Andhratharhi'],
      'Phulparas': ['Phulparas', 'Ghoghardiha', 'Khutauna', 'Laukaha', 'Babubarhi'],
    },
    'SAHARSA': {
      'Saharsa Sadar': ['Kahara', 'Sattar Katiya', 'Saur Bazar', 'Patarghat', 'Mahishi', 'Nauhatta', 'Sonbarsa'],
      'Simri Bakhtiyarpur': ['Simri Bakhtiyarpur', 'Salkhua', 'Banma Itahari'],
    },
    'MADHEPURA': {
      'Madhepura Sadar': ['Madhepura', 'Singheshwar', 'Gamharia', 'Ghelarh', 'Shankarpur', 'Murliganj'],
      'Udakishunganj': ['Udakishunganj', 'Alamnagar', 'Chausa', 'Puraini', 'Biharganj', 'Kumarkhand'],
    },
    'SUPAUL': {
      'Supaul Sadar': ['Supaul', 'Kishanpur', 'Saraigarh Bhaptiyahi', 'Pipra', 'Marauna'],
      'Birpur': ['Basantpur', 'Raghopur', 'Chhatapur'],
      'Nirmali': ['Nirmali'],
      'Triveniganj': ['Triveniganj', 'Jadupati'],
    },
    'KATIHAR': {
      'Katihar Sadar': ['Katihar', 'Korha', 'Falka', 'Hasanganj', 'Dandkhora', 'Mansahi'],
      'Barsoi': ['Barsoi', 'Kadwa', 'Azamnagar', 'Balrampur'],
      'Manihari': ['Manihari', 'Amdabad', 'Sameli', 'Pranpur'],
    },
    'KISHANGANJ': {
      'Kishanganj': ['Kishanganj', 'Kochadhaman', 'Bahadurganj', 'Thakurganj', 'Pothia', 'Terhagachh', 'Dighalbank'],
    },
    'ARARIA': {
      'Araria Sadar': ['Araria', 'Jokihat', 'Kursakatta', 'Raniganj', 'Palasi', 'Sikti'],
      'Forbesganj': ['Forbesganj', 'Bhargama', 'Narpatganj'],
    },
    'AURANGABAD': {
      'Aurangabad Sadar': ['Aurangabad', 'Barun', 'Navinagar', 'Kutumba', 'Madanpur', 'Deo'],
      'Daudnagar': ['Daudnagar', 'Obra', 'Goh', 'Haspura', 'Rafiganj'],
    },
    'NAWADA': {
      'Nawada Sadar': ['Nawada', 'Warisliganj', 'Kashichak', 'Pakribarawan', 'Kawakol', 'Roh', 'Hisua', 'Nardiganj'],
      'Rajauli': ['Rajauli', 'Akbarpur', 'Govindpur', 'Sirdala', 'Meskaur'],
    },
    'JEHANABAD': {
      'Jehanabad': ['Jehanabad', 'Kako', 'Modanganj', 'Ghoshi', 'Makhdumpur', 'Hulasganj', 'Ratni Faridpur'],
    },
    'ARWAL': {
      'Arwal': ['Arwal', 'Kaler', 'Karpi', 'Kurtha', 'Sonbhadra Banshi Suryapur'],
    },
    'JAMUI': {
      'Jamui': ['Jamui', 'Khaira', 'Barhat', 'Gidhaur', 'Jhajha', 'Sono', 'Chakai', 'Sikandra', 'Aliganj'],
    },
    'BANKA': {
      'Banka': ['Banka', 'Barahat', 'Rajaun', 'Amarpur', 'Dhuraiya', 'Belhar', 'Chandan', 'Katoria', 'Bounsi', 'Phulidumar', 'Shambhuganj'],
    },
    'MUNGER': {
      'Munger Sadar': ['Munger', 'Jamalpur', 'Bariarpur', 'Dharhara'],
      'Haveli Kharagpur': ['Haveli Kharagpur', 'Tetiyabambar'],
      'Tarapur': ['Tarapur', 'Asarganj', 'Sangrampur'],
    },
    'KHAGARIA': {
      'Khagaria Sadar': ['Khagaria', 'Alauli', 'Mansi', 'Chautham'],
      'Gogri': ['Gogri', 'Beldaur', 'Parbatta'],
    },
    'LAKHISARAI': {
      'Lakhisarai': ['Lakhisarai', 'Barahiya', 'Halsi', 'Pipariya', 'Ramgarh Chowk', 'Channani'],
    },
    'SHEIKHPURA': {
      'Sheikhpura': ['Sheikhpura', 'Barbigha', 'Shekhopur Sarai', 'Ariari', 'Chewara', 'Ghatkusumbha'],
    },
    'BUXAR': {
      'Buxar Sadar': ['Buxar', 'Itarhi', 'Chausa', 'Rajpur'],
      'Dumraon': ['Dumraon', 'Nawanagar', 'Brahampur', 'Kesath', 'Chakki', 'Chougain', 'Simri'],
    },
    'KAIMUR (BHABHUA)': {
      'Bhabhua': ['Bhabhua', 'Bhagwanpur', 'Chainpur', 'Chand', 'Adhaura', 'Rampur'],
      'Mohania': ['Mohania', 'Kudra', 'Durgawati', 'Ramgarh'],
    },
    'SHEOHAR': {
      'Sheohar': ['Sheohar', 'Tariani Chowk', 'Piprahi', 'Dumri Katsari', 'Purnahiya'],
    },
    'SITAMARHI': {
      'Sitamarhi Sadar': ['Dumra', 'Riga', 'Bairgania', 'Suppi', 'Parsauni', 'Majorganj', 'Sonbarsa', 'Bathanaha'],
      'Belsand': ['Belsand', 'Runnisaidpur'],
      'Pupri': ['Pupri', 'Nanpur', 'Bajpatti', 'Sursand', 'Parihar', 'Choraut', 'Bokhara'],
    },
  };

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
        _policeStation.text = d['police_station'] ?? '';
        _purpose.text = d['purpose'] ?? 'उच्च शिक्षण / सरकारी नौकरी';

        _gender = d['gender'] ?? 'MALE';
        _localBodyType = d['local_body_type'] ?? 'Gram Panchayat (ग्राम पंचायत)';
        _residenceType = d['residence_type'] ?? 'स्थायी (Permanent)';
        _profession = d['profession'] ?? 'छात्र (Student)';

        final dist = d['district'] ?? 'PATNA';
        if (_biharAdminData.containsKey(dist)) {
          _selectedDistrict = dist;
          final subDivs = _biharAdminData[dist]!.keys.toList();
          final savedSub = d['sub_division'];
          if (subDivs.contains(savedSub)) {
            _selectedSubDiv = savedSub;
            final blocks = _biharAdminData[dist]![savedSub]!;
            final savedBlock = d['block'];
            if (blocks.contains(savedBlock)) {
              _selectedBlock = savedBlock;
            }
          }
        }

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
    } else {
      _selectedSubDiv = _biharAdminData['PATNA']!.keys.first;
      _selectedBlock = _biharAdminData['PATNA']![_selectedSubDiv]!.first;
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
        const SnackBar(content: Text('⚠️ Kripya laal (*) wale sabhi aniwarya fields bharein!')),
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
      'sub_division': _selectedSubDiv?.trim() ?? '',
      'block': _selectedBlock?.trim() ?? '',
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RTPS Master Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text('Ek baar bharein • Har form me auto-fill karein', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1E1B18) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          children: [
            _buildLegendBar(),
            const SizedBox(height: 14),

            // 1. Personal Details
            _buildSectionHeader('1. Vyaktigat Vivaran (Personal Info)', Icons.person_rounded),
            _buildCard([
              _buildGenderSelector(),
              const SizedBox(height: 12),
              _buildFieldWithLabel('Aavedak Ka Naam (English)', _nameEn, isRequired: true, hint: 'e.g. AMIT KUMAR'),
              _buildFieldWithLabel('आवेदक का नाम (Hindi)', _nameHi, isRequired: true, hint: 'e.g. अमित कुमार'),
              _buildFieldWithLabel("Pita Ka Naam (Father's Name in English)", _fatherEn, isRequired: true, hint: 'e.g. RAMESH PRASAD'),
              _buildFieldWithLabel("पिता का नाम (Hindi)", _fatherHi, isRequired: true, hint: 'e.g. रमेश प्रसाद'),
              _buildFieldWithLabel("Mata Ka Naam (Mother's Name in English)", _motherEn, isRequired: true, hint: 'e.g. SHANTI DEVI'),
              _buildFieldWithLabel("माता का नाम (Hindi)", _motherHi, isRequired: true, hint: 'e.g. शान्ति देवी'),
              _buildFieldWithLabel("Pati Ka Naam (Husband Name in English)", _husbandEn, isRequired: false, hint: 'Vivahit mahilao ke liye'),
              _buildFieldWithLabel("पति का नाम (Hindi)", _husbandHi, isRequired: false, hint: 'यदि लागू हो'),
            ], cardBg),
            const SizedBox(height: 16),

            // 2. Contact & Location Details
            _buildSectionHeader('2. Sampark & Sthan (Contact & Location)', Icons.location_on_rounded),
            _buildCard([
              _buildFieldWithLabel('Mobile Number (OTP isi par aayega)', _mobile, isRequired: true, keyboard: TextInputType.phone, hint: '10-digit mobile number'),
              _buildFieldWithLabel('Email Address (Certificate mail par aayega)', _email, isRequired: false, keyboard: TextInputType.emailAddress, hint: 'name@example.com'),
              const SizedBox(height: 10),

              // 🏛️ CASCADING DROPDOWNS: District -> SubDivision -> Block
              _buildDropdownHeader('Zila (District)', isRequired: true),
              DropdownButtonFormField<String>(
                value: _selectedDistrict,
                decoration: _inputDecoration('Select District'),
                items: _biharAdminData.keys.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedDistrict = val;
                      final subDivs = _biharAdminData[val]!.keys.toList();
                      _selectedSubDiv = subDivs.isNotEmpty ? subDivs.first : null;
                      final blocks = _selectedSubDiv != null ? _biharAdminData[val]![_selectedSubDiv]! : <String>[];
                      _selectedBlock = blocks.isNotEmpty ? blocks.first : null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              _buildDropdownHeader('Anumandal (Sub-Division)', isRequired: true),
              DropdownButtonFormField<String>(
                value: _selectedSubDiv,
                decoration: _inputDecoration('Select Sub-Division'),
                items: (_biharAdminData[_selectedDistrict]?.keys.toList() ?? []).map((sd) => DropdownMenuItem(value: sd, child: Text(sd, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedSubDiv = val;
                      final blocks = _biharAdminData[_selectedDistrict]![val] ?? [];
                      _selectedBlock = blocks.isNotEmpty ? blocks.first : null;
                    });
                  }
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Anumandal chunna aniwarya hai' : null,
              ),
              const SizedBox(height: 12),

              _buildDropdownHeader('Prakhand (Block)', isRequired: true),
              DropdownButtonFormField<String>(
                value: _selectedBlock,
                decoration: _inputDecoration('Select Block'),
                items: (_biharAdminData[_selectedDistrict]?[_selectedSubDiv] ?? []).map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (val) => setState(() => _selectedBlock = val),
                validator: (v) => (v == null || v.isEmpty) ? 'Block chunna aniwarya hai' : null,
              ),
              const SizedBox(height: 12),

              _buildFieldWithLabel('Thana (Police Station)', _policeStation, isRequired: true, hint: 'e.g. Danapur / Kankarbagh'),
              _buildFieldWithLabel('Ward No', _wardNo, isRequired: false, keyboard: TextInputType.number, hint: 'Ward number yadi ho'),
              _buildFieldWithLabel('Gaon / Mohalla (Village / Town)', _village, isRequired: true, hint: 'e.g. Saguna More / Rampur'),
              _buildFieldWithLabel('Dakghar (Post Office)', _postOffice, isRequired: true, hint: 'Post Office ka naam'),
              _buildFieldWithLabel('Pin Code', _pinCode, isRequired: true, keyboard: TextInputType.number, hint: '6-digit pincode'),

              const SizedBox(height: 6),
              _buildDropdownHeader('Sthaniya Nikay Ka Prakar (Local Body)', isRequired: false),
              DropdownButtonFormField<String>(
                value: _localBodyType,
                decoration: _inputDecoration('Local Body'),
                items: [
                  'Gram Panchayat (ग्राम पंचायत)',
                  'Nagar Nigam (नगर निगम)',
                  'Nagar Parishad (नगर परिषद्)',
                  'Nagar Panchayat (नगर पंचायत)',
                ].map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (v) => setState(() => _localBodyType = v ?? _localBodyType),
              ),
            ], cardBg),
            const SizedBox(height: 16),

            // 3. Caste & Profession Details
            _buildSectionHeader('3. Jati & Pesha (Caste & Profession)', Icons.badge_rounded),
            _buildCard([
              _buildDropdownHeader('Pesha (Profession)', isRequired: true),
              DropdownButtonFormField<String>(
                value: _profession,
                decoration: _inputDecoration('Select Profession'),
                items: [
                  'छात्र (Student)',
                  'सरकारी सेवा (Govt Service)',
                  'निजी सेवा (Private Service)',
                  'व्यापार (Business)',
                  'किसान (Farmer)',
                  'गृहणी (Housewife)',
                  'अन्य (Other)'
                ].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _profession = v ?? _profession),
              ),
              const SizedBox(height: 12),

              _buildFieldWithLabel('Aavedan Ka Uddeshya (Purpose)', _purpose, isRequired: true, hint: 'उच्च शिक्षण / सरकारी नौकरी'),

              _buildDropdownHeader('Caste Category (वर्ग)', isRequired: true),
              DropdownButtonFormField<String>(
                value: _casteCategory,
                decoration: _inputDecoration('Select Category'),
                items: [
                  'अत्यंत पिछड़ा वर्ग (अनुसूची-1) / EBC',
                  'पिछड़ा वर्ग (अनुसूची-2) / BC',
                  'अनुसूचित जाति / SC',
                  'अनुसूचित जनजाति / ST',
                  'गैर-आरक्षित (General / EWS)'
                ].map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12.5)))).toList(),
                onChanged: (v) => setState(() => _casteCategory = v ?? _casteCategory),
              ),
              const SizedBox(height: 12),

              _buildFieldWithLabel('Jati Ka Naam (Caste)', _casteName, isRequired: true, hint: 'e.g. Kushwaha / Yadav / Kurmi / Teli / Paswan'),
            ], cardBg),
            const SizedBox(height: 16),

            // 4. Income Details
            _buildSectionHeader('4. Aay Ka Vivaran (Annual Income in Rs)', Icons.currency_rupee_rounded),
            _buildCard([
              _buildFieldWithLabel('Sarkari Seva Se Aay (Govt Income)', _incomeGovt, isRequired: false, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              _buildFieldWithLabel('Krishi Se Aay (Agriculture Income)', _incomeAgri, isRequired: false, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              _buildFieldWithLabel('Vyavsayik Aay (Business Income)', _incomeBiz, isRequired: false, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              _buildFieldWithLabel('Anya Shroton Se Aay (Other Sources)', _incomeOther, isRequired: false, keyboard: TextInputType.number, onChanged: (_) => _calculateTotalIncome()),
              _buildFieldWithLabel('Kul Varshik Aay (Total Income)', _incomeTotal, isRequired: true, keyboard: TextInputType.number, hint: 'Auto-calculated'),
            ], cardBg),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
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

  Widget _buildLegendBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
              SizedBox(width: 8),
              Text('Field Indicators (संकेत):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('* लाल (Red)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Aniwarya hai (Mandatory — portal par required hai).', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('Grey', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Vaekalpik hai (Optional — khali chhod sakte hain).', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              ),
            ],
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
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

  Widget _buildFieldWithLabel(
    String label,
    TextEditingController ctrl, {
    required bool isRequired,
    String? hint,
    TextInputType keyboard = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              if (isRequired) ...[
                const SizedBox(width: 4),
                const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(width: 4),
                const Text('(Mandatory)', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
              ] else ...[
                const SizedBox(width: 4),
                const Text('(Optional)', style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ],
          ),
          const SizedBox(height: 5),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboard,
            onChanged: onChanged,
            validator: (v) {
              if (isRequired && (v == null || v.trim().isEmpty)) {
                return '$label aniwarya hai';
              }
              return null;
            },
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: _inputDecoration(hint ?? label),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownHeader(String label, {required bool isRequired}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          if (isRequired) ...[
            const SizedBox(width: 4),
            const Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 4),
            const Text('(Mandatory)', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        const Text('Gender *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
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
}
