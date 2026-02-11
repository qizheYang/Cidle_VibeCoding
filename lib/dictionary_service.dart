import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'pinyin_utils.dart';

class ChineseWord {
  final String characters;
  final List<String> pinyinList;

  ChineseWord(this.characters, this.pinyinList);

  List<PinyinSyllable> get syllables =>
      pinyinList.map((p) => PinyinUtils.separate(p)).toList();

  int get length => characters.length;

  ChineseWord copyWithPinyin(List<String> newPinyin) {
    return ChineseWord(characters, newPinyin);
  }
}

class DictionaryService {
  static final DictionaryService _instance = DictionaryService._internal();
  factory DictionaryService() => _instance;
  DictionaryService._internal();

  // Proxy URL for secure API calls (Cloudflare Worker)
  String? _proxyUrl;

  void setProxyUrl(String url) {
    _proxyUrl = url;
    print('[DictionaryService] Proxy URL set to: $_proxyUrl');
  }

  bool get hasProxy => _proxyUrl != null && _proxyUrl!.isNotEmpty;

  // Track used words to avoid repetition
  final Set<String> _usedWords = {};

  void resetUsedWords() {
    _usedWords.clear();
  }

  bool get hasApiKey => hasProxy;

  /// Lookup pinyin using Cloudflare Worker proxy → OpenAI
  Future<List<String>?> _lookupPinyinFromProxy(String characters) async {
    if (!hasProxy) {
      print('[DictionaryService] No proxy configured, skipping proxy lookup');
      return null;
    }

    try {
      final url = '$_proxyUrl/pinyin';
      print('[DictionaryService] Calling proxy: $url for "$characters"');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'characters': characters,
        }),
      ).timeout(const Duration(seconds: 10));

      print('[DictionaryService] Proxy response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String?;
        print('[DictionaryService] Proxy response content: $content');

        if (content != null) {
          final cleaned = content
              .toUpperCase()
              .replaceAll(RegExp(r'[^A-Z\s]'), '')
              .trim();

          final syllables = cleaned
              .split(RegExp(r'\s+'))
              .where((s) => s.isNotEmpty)
              .map((s) => _validateAndNormalizePinyin(s))
              .where((s) => s != null)
              .cast<String>()
              .toList();

          print('[DictionaryService] Parsed syllables: $syllables (expected ${characters.length})');

          if (syllables.length == characters.length) {
            return syllables;
          }
        }
      }
    } catch (e) {
      print('[DictionaryService] Proxy call failed: $e');
    }
    return null;
  }

  String? _validateAndNormalizePinyin(String pinyin) {
    final upper = pinyin.toUpperCase().trim();
    if (!RegExp(r'^[A-Z]+$').hasMatch(upper)) return null;
    if (upper.isEmpty || upper.length > 6) return null;
    return upper;
  }

  // Cache for pinyin lookups
  final Map<String, List<String>> _pinyinCache = {};

  // Common 多音字 with their pronunciations
  static const Map<String, List<String>> _polyphonicChars = {
    '行': ['XING', 'HANG'],
    '长': ['CHANG', 'ZHANG'],
    '乐': ['LE', 'YUE'],
    '发': ['FA', 'FĀ'],
    '重': ['ZHONG', 'CHONG'],
    '数': ['SHU', 'SHUO'],
    '还': ['HAI', 'HUAN'],
    '着': ['ZHE', 'ZHAO', 'ZHUO', 'ZHU'],
    '地': ['DI', 'DE'],
    '得': ['DE', 'DEI', 'DĒ'],
    '了': ['LE', 'LIAO'],
    '好': ['HAO', 'HĀO'],
    '大': ['DA', 'DAI'],
    '少': ['SHAO', 'SHǍO'],
    '为': ['WEI', 'WÈI'],
    '种': ['ZHONG', 'ZHǑNG'],
    '会': ['HUI', 'KUAI'],
    '只': ['ZHI', 'ZHĪ'],
    '相': ['XIANG', 'XIĀNG'],
    '便': ['BIAN', 'PIAN'],
    '都': ['DOU', 'DŪ'],
    '教': ['JIAO', 'JIĀO'],
    '空': ['KONG', 'KŌNG'],
    '看': ['KAN', 'KĀN'],
    '难': ['NAN', 'NÀN'],
    '落': ['LUO', 'LA', 'LÀO'],
    '干': ['GAN', 'GĀN'],
    '弹': ['DAN', 'TAN'],
    '倒': ['DAO', 'DĀO'],
    '将': ['JIANG', 'JIĀNG'],
    '差': ['CHA', 'CHAI', 'CHĀ', 'CI'],
    '调': ['DIAO', 'TIAO'],
    '传': ['CHUAN', 'ZHUÀN'],
    '冲': ['CHONG', 'CHŌNG'],
    '强': ['QIANG', 'JIÀNG', 'QIǍNG'],
    '背': ['BEI', 'BÈI'],
    '切': ['QIE', 'QIĒ'],
    '觉': ['JUE', 'JIÀO'],
    '奇': ['QI', 'JĪ'],
    '处': ['CHU', 'CHǓ'],
    '参': ['CAN', 'SHĒN', 'CĒN'],
    '藏': ['CANG', 'ZÀNG'],
    '担': ['DAN', 'DĀN', 'DÀN'],
    '当': ['DANG', 'DÀNG'],
    '度': ['DU', 'DUÒ'],
    '分': ['FEN', 'FÈN'],
    '缝': ['FENG', 'FÈNG'],
    '和': ['HE', 'HUÒ', 'HÚ', 'HUO'],
    '假': ['JIA', 'JIǍ'],
    '间': ['JIAN', 'JIÀN'],
    '角': ['JIAO', 'JUÉ'],
    '结': ['JIE', 'JIĒ'],
    '卷': ['JUAN', 'JUǍN'],
    '累': ['LEI', 'LÈI', 'LĚI'],
    '量': ['LIANG', 'LIÀNG'],
    '露': ['LU', 'LÒU'],
    '埋': ['MAI', 'MÁN'],
    '磨': ['MO', 'MÒ'],
    '宁': ['NING', 'NÌNG'],
    '撒': ['SA', 'SǍ'],
    '散': ['SAN', 'SÀN'],
    '舍': ['SHE', 'SHĚ'],
    '省': ['SHENG', 'XǏNG'],
    '识': ['SHI', 'ZHÌ'],
    '似': ['SI', 'SHÌ'],
    '恶': ['E', 'WÙ', 'Ě'],
    '晃': ['HUANG', 'HUǍNG'],
  };

  // Single character pinyin map for common characters (fallback)
  static const Map<String, String> _singleCharPinyin = {
    '的': 'DE', '一': 'YI', '是': 'SHI', '不': 'BU', '在': 'ZAI',
    '人': 'REN', '有': 'YOU', '我': 'WO', '他': 'TA', '这': 'ZHE', '个': 'GE',
    '们': 'MEN', '来': 'LAI', '上': 'SHANG', '大': 'DA', '国': 'GUO',
    '到': 'DAO', '说': 'SHUO', '要': 'YAO', '就': 'JIU', '出': 'CHU',
    '也': 'YE', '你': 'NI', '对': 'DUI', '能': 'NENG', '而': 'ER',
    '子': 'ZI', '那': 'NA', '于': 'YU', '下': 'XIA', '之': 'ZHI',
    '过': 'GUO', '后': 'HOU', '作': 'ZUO', '里': 'LI', '用': 'YONG',
    '所': 'SUO', '然': 'RAN', '事': 'SHI', '成': 'CHENG', '方': 'FANG',
    '多': 'DUO', '么': 'ME', '去': 'QU', '如': 'RU', '同': 'TONG',
    '现': 'XIAN', '没': 'MEI', '面': 'MIAN', '起': 'QI', '定': 'DING',
    '进': 'JIN', '小': 'XIAO', '些': 'XIE', '样': 'YANG', '心': 'XIN',
    '本': 'BEN', '但': 'DAN', '从': 'CONG', '日': 'RI', '军': 'JUN',
    '无': 'WU', '把': 'BA', '十': 'SHI', '民': 'MIN', '公': 'GONG',
    '感': 'GAN', '最': 'ZUI', '外': 'WAI', '体': 'TI', '全': 'QUAN',
    '等': 'DENG', '被': 'BEI', '很': 'HEN', '知': 'ZHI', '又': 'YOU',
    '入': 'RU', '次': 'CI', '三': 'SAN', '总': 'ZONG', '给': 'GEI',
    '口': 'KOU', '每': 'MEI', '品': 'PIN', '让': 'RANG', '根': 'GEN',
    '受': 'SHOU', '放': 'FANG', '任': 'REN', '完': 'WAN', '白': 'BAI',
    '表': 'BIAO', '五': 'WU', '四': 'SI', '系': 'XI', '六': 'LIU',
    '特': 'TE', '身': 'SHEN', '目': 'MU', '光': 'GUANG', '走': 'ZOU',
    '比': 'BI', '员': 'YUAN', '取': 'QU', '头': 'TOU', '代': 'DAI',
    '则': 'ZE', '平': 'PING', '更': 'GENG', '内': 'NEI', '候': 'HOU',
    '八': 'BA', '决': 'JUE', '保': 'BAO', '各': 'GE', '打': 'DA',
    '海': 'HAI', '点': 'DIAN', '求': 'QIU', '象': 'XIANG', '论': 'LUN',
    '七': 'QI', '流': 'LIU', '至': 'ZHI', '九': 'JIU', '观': 'GUAN',
    '词': 'CI', '汇': 'HUI', '单': 'DAN', '睿': 'RUI', '习': 'XI',
    '拼': 'PIN', '韵': 'YUN', '读': 'DU', '句': 'JU', '段': 'DUAN',
    '籍': 'JI', '写': 'XIE', '绩': 'JI', '姐': 'JIE', '妹': 'MEI',
    '今': 'JIN', '午': 'WU', '昨': 'ZUO', '丽': 'LI', '漂': 'PIAO',
    '努': 'NU', '败': 'BAI', '案': 'AN', '杂': 'ZA', '需': 'XU',
    '讨': 'TAO', '支': 'ZHI', '帮': 'BANG', '助': 'ZHU', '赛': 'SAI',
    '途': 'TU', '废': 'FEI', '诚': 'CHENG', '独': 'DU', '二': 'ER',
    '秋': 'QIU', '龙': 'LONG', '睛': 'JING', '勇': 'YONG', '益': 'YI',
    '辟': 'PI', '凤': 'FENG', '副': 'FU', '死': 'SI', '屈': 'QU',
    '釜': 'FU', '沉': 'CHEN', '舟': 'ZHOU', '千': 'QIAN', '百': 'BAI',
    '众': 'ZHONG', '致': 'ZHI', '踏': 'TA', '株': 'ZHU', '待': 'DAI',
    '兔': 'TU', '狐': 'HU', '威': 'WEI', '添': 'TIAN', '足': 'ZU',
    '刻': 'KE', '蛙': 'WA', '掩': 'YAN', '盗': 'DAO', '铃': 'LING',
    '矛': 'MAO', '盾': 'DUN', '梦': 'MENG', '挑': 'TIAO', '容': 'RONG',
    '选': 'XUAN', '择': 'ZE', '忆': 'YI', '练': 'LIAN', '卷': 'JUAN',
    '城': 'CHENG', '春': 'CHUN', '夏': 'XIA', '东': 'DONG', '西': 'XI',
    '南': 'NAN', '北': 'BEI', '左': 'ZUO', '右': 'YOU', '书': 'SHU',
    '包': 'BAO', '纸': 'ZHI', '笔': 'BI', '桌': 'ZHUO', '椅': 'YI',
    '床': 'CHUANG', '灯': 'DENG', '楼': 'LOU', '店': 'DIAN', '饭': 'FAN',
    '菜': 'CAI', '肉': 'ROU', '鱼': 'YU', '鸡': 'JI', '米': 'MI',
    '茶': 'CHA', '咖': 'KA', '啡': 'FEI', '杯': 'BEI', '碗': 'WAN',
    '盘': 'PAN', '筷': 'KUAI', '勺': 'SHAO', '叉': 'CHA', '车': 'CHE',
    '票': 'PIAO', '港': 'GANG', '桥': 'QIAO', '河': 'HE', '湖': 'HU',
    '村': 'CUN', '镇': 'ZHEN', '县': 'XIAN', '京': 'JING', '深': 'SHEN',
    '穿': 'CHUAN', '裤': 'KU', '鞋': 'XIE', '帽': 'MAO', '袜': 'WA',
    '裙': 'QUN', '衫': 'SHAN', '块': 'KUAI', '元': 'YUAN', '万': 'WAN',
    '亿': 'YI', '零': 'LING', '双': 'SHUANG', '整': 'ZHENG', '够': 'GOU',
    '病': 'BING', '药': 'YAO', '针': 'ZHEN', '痛': 'TONG', '热': 'RE',
    '冷': 'LENG', '饿': 'E', '渴': 'KE', '醒': 'XING', '睡': 'SHUI',
    '哭': 'KU', '怒': 'NU', '惧': 'JU', '悲': 'BEI', '忧': 'YOU',
    '愁': 'CHOU', '念': 'NIAN', '忘': 'WANG', '恨': 'HEN', '怕': 'PA',
    '敢': 'GAN', '愿': 'YUAN', '该': 'GAI', '须': 'XU', '算': 'SUAN',
    '猜': 'CAI', '错': 'CUO', '换': 'HUAN', '增': 'ZENG', '寻': 'XUN',
    '找': 'ZHAO', '搜': 'SOU', '索': 'SUO', '验': 'YAN', '测': 'CE',
    '画': 'HUA', '图': 'TU', '片': 'PIAN', '刷': 'SHUA', '扫': 'SAO',
    '描': 'MIAO', '听': 'TING', '谈': 'TAN', '聊': 'LIAO', '告': 'GAO',
    '诉': 'SU', '抱': 'BAO', '歉': 'QIAN', '再': 'ZAI', '迎': 'YING',
    '送': 'SONG', '别': 'BIE', '近': 'JIN', '远': 'YUAN', '慢': 'MAN',
    '迟': 'CHI', '准': 'ZHUN', '确': 'QUE', '误': 'WU', '满': 'MAN',
    '虚': 'XU', '旧': 'JIU', '暖': 'NUAN', '甜': 'TIAN', '辣': 'LA',
    '咸': 'XIAN', '臭': 'CHOU', '脏': 'ZANG', '湿': 'SHI', '粗': 'CU',
    '厚': 'HOU', '宽': 'KUAN', '窄': 'ZHAI', '浅': 'QIAN', '扁': 'BIAN',
    '钝': 'DUN', '紧': 'JIN', '松': 'SONG', '稳': 'WEN', '乱': 'LUAN',
    '齐': 'QI', '顺': 'SHUN', '逆': 'NI', '横': 'HENG', '竖': 'SHU',
    '弯': 'WAN', '折': 'ZHE', '连': 'LIAN', '续': 'XU', '停': 'TING',
    '守': 'SHOU', '防': 'FANG', '护': 'HU', '害': 'HAI', '损': 'SUN',
    '亡': 'WANG', '存': 'CUN', '养': 'YANG', '喂': 'WEI', '吃': 'CHI',
    '吸': 'XI', '吹': 'CHUI', '呼': 'HU', '喊': 'HAN', '玩': 'WAN',
    '耍': 'SHUA', '闹': 'NAO', '闲': 'XIAN', '忙': 'MANG', '懒': 'LAN',
    '勤': 'QIN', '穷': 'QIONG', '贵': 'GUI', '尊': 'ZUN', '卑': 'BEI',
    '雅': 'YA', '俗': 'SU', '善': 'SHAN', '丑': 'CHOU', '胖': 'PANG',
    '矮': 'AI', '男': 'NAN', '女': 'NV', '孩': 'HAI', '童': 'TONG',
    '壮': 'ZHUANG', '岁': 'SUI', '伍': 'WU', '排': 'PAI', '列': 'LIE',
    '编': 'BIAN', '码': 'MA', '秘': 'MI', '私': 'SI', '隐': 'YIN',
    '显': 'XIAN', '注': 'ZHU', '译': 'YI', '版': 'BAN', '典': 'DIAN',
    '故': 'GU', '船': 'CHUAN', '飞': 'FEI', '蛋': 'DAN', '窗': 'CHUANG',
    '报': 'BAO', '酒': 'JIU', '刀': 'DAO', '钱': 'QIAN', '毛': 'MAO',
    '医': 'YI', '院': 'YUAN', '笑': 'XIAO', '思': 'SI', '改': 'GAI',
    '除': 'CHU', '减': 'JIAN', '乘': 'CHENG', '照': 'ZHAO', '像': 'XIANG',
    '印': 'YIN', '请': 'QING', '谢': 'XIE', '离': 'LI', '香': 'XIANG',
    '净': 'JING', '轻': 'QING', '细': 'XI', '薄': 'BAO', '圆': 'YUAN',
    '尖': 'JIAN', '锋': 'FENG', '斜': 'XIE', '曲': 'QU', '断': 'DUAN',
    '留': 'LIU', '攻': 'GONG', '救': 'JIU', '伤': 'SHANG', '唱': 'CHANG',
    '跳': 'TIAO', '静': 'JING', '富': 'FU', '贱': 'JIAN', '瘦': 'SHOU',
    '青': 'QING', '示': 'SHI', '释': 'SHI', '权': 'QUAN', '字': 'ZI',
    '年': 'NIAN', '学': 'XUE', '生': 'SHENG', '工': 'GONG', '活': 'HUO',
    '经': 'JING', '济': 'JI', '社': 'SHE', '科': 'KE', '术': 'SHU',
    '政': 'ZHENG', '界': 'JIE', '家': 'JIA', '市': 'SHI', '场': 'CHANG',
    '业': 'YE', '管': 'GUAN', '研': 'YAN', '究': 'JIU', '设': 'SHE',
    '产': 'CHAN', '质': 'ZHI', '量': 'LIANG', '健': 'JIAN', '康': 'KANG',
    '环': 'HUAN', '境': 'JING', '资': 'ZI', '源': 'YUAN', '交': 'JIAO',
    '通': 'TONG', '网': 'WANG', '络': 'LUO', '信': 'XIN', '息': 'XI',
    '据': 'JU', '脑': 'NAO', '手': 'SHOU', '机': 'JI', '软': 'RUAN',
    '硬': 'YING', '游': 'YOU', '戏': 'XI', '音': 'YIN', '乐': 'YUE',
    '影': 'YING', '运': 'YUN', '动': 'DONG', '旅': 'LV', '朋': 'PENG',
    '友': 'YOU', '庭': 'TING', '爱': 'AI', '情': 'QING', '幸': 'XING',
    '福': 'FU', '快': 'KUAI', '展': 'ZHAN', '新': 'XIN', '老': 'LAO',
    '明': 'MING', '高': 'GAO', '第': 'DI', '先': 'XIAN', '回': 'HUI',
    '加': 'JIA', '认': 'REN', '共': 'GONG', '合': 'HE', '结': 'JIE',
    '真': 'ZHEN', '水': 'SHUI', '利': 'LI', '反': 'FAN', '果': 'GUO',
    '直': 'ZHI', '级': 'JI', '路': 'LU', '组': 'ZU', '山': 'SHAN',
    '统': 'TONG', '区': 'QU', '形': 'XING', '解': 'JIE', '美': 'MEI',
    '接': 'JIE', '式': 'SHI', '月': 'YUE', '建': 'JIAN', '望': 'WANG',
    '向': 'XIANG', '义': 'YI', '争': 'ZHENG', '记': 'JI', '标': 'BIAO',
    '困': 'KUN', '难': 'NAN', '简': 'JIAN', '必': 'BI', '喜': 'XI',
    '欢': 'HUAN', '相': 'XIANG', '见': 'JIAN', '原': 'YUAN', '做': 'ZUO',
    '门': 'MEN', '几': 'JI', '位': 'WEI', '即': 'JI', '当': 'DANG',
    '前': 'QIAN', '开': 'KAI', '因': 'YIN', '只': 'ZHI', '想': 'XIANG',
    '实': 'SHI', '意': 'YI', '力': 'LI', '它': 'TA', '与': 'YU',
    '长': 'CHANG', '此': 'CI', '已': 'YI', '使': 'SHI', '正': 'ZHENG',
    '制': 'ZHI', '度': 'DU', '两': 'LIANG', '她': 'TA', '者': 'ZHE',
    '得': 'DE', '着': 'ZHE', '了': 'LE', '为': 'WEI', '中': 'ZHONG',
    '地': 'DI', '以': 'YI', '可': 'KE', '天': 'TIAN', '分': 'FEN',
    '还': 'HAI', '好': 'HAO', '部': 'BU', '其': 'QI', '主': 'ZHU',
    '看': 'KAN', '行': 'XING', '种': 'ZHONG', '法': 'FA', '都': 'DOU',
    '发': 'FA', '道': 'DAO', '重': 'ZHONG', '少': 'SHAO', '母': 'MU',
    '父': 'FU', '兄': 'XIONG', '弟': 'DI', '师': 'SHI', '校': 'XIAO',
    '室': 'SHI', '试': 'SHI', '考': 'KAO', '章': 'ZHANG', '落': 'LUO',
    '节': 'JIE', '声': 'SHENG', '晚': 'WAN', '早': 'ZAO', '冬': 'DONG',
    '亮': 'LIANG', '聪': 'CONG', '功': 'GONG', '答': 'DA', '复': 'FU',
    '希': 'XI', '调': 'DIAO',
    '风': 'FENG', '精': 'JING', '破': 'PO', '虎': 'HU', '蛇': 'SHE',
    '井': 'JING', '底': 'DI', '叶': 'YE', '战': 'ZHAN', '脚': 'JIAO',
    '藏': 'CANG', '担': 'DAN', '缝': 'FENG', '角': 'JIAO', '累': 'LEI',
    '露': 'LU', '埋': 'MAI', '撒': 'SA', '散': 'SAN', '舍': 'SHE',
    '省': 'SHENG', '似': 'SI', '恶': 'E', '晃': 'HUANG', '传': 'CHUAN',
    '冲': 'CHONG', '强': 'QIANG', '背': 'BEI', '切': 'QIE', '觉': 'JUE',
    '奇': 'QI', '处': 'CHU', '参': 'CAN', '倒': 'DAO', '将': 'JIANG',
    '差': 'CHA', '弹': 'DAN', '干': 'GAN', '宁': 'NING', '磨': 'MO',
    '衣': 'YI', '州': 'ZHOU', '江': 'JIANG', '广': 'GUANG', '沪': 'HU',
    '号': 'HAO', '期': 'QI', '季': 'JI', '假': 'JIA', '班': 'BAN',
    '队': 'DUI', '舞': 'WU', '台': 'TAI', '司': 'SI', '局': 'JU',
    '委': 'WEI', '办': 'BAN', '厅': 'TING', '股': 'GU', '份': 'FEN',
    '物': 'WU', '价': 'JIA', '格': 'GE', '牌': 'PAI', '商': 'SHANG',
    '贸': 'MAO', '投': 'TOU', '金': 'JIN', '融': 'RONG', '险': 'XIAN',
    '税': 'SHUI', '费': 'FEI', '款': 'KUAN', '债': 'ZHAI', '券': 'QUAN',
    '基': 'JI', '户': 'HU', '账': 'ZHANG', '证': 'ZHENG', '卡': 'KA',
    '登': 'DENG', '录': 'LU', '册': 'CE', '页': 'YE', '链': 'LIAN',
    '按': 'AN', '钮': 'NIU', '键': 'JIAN', '鼠': 'SHU', '屏': 'PING',
    '幕': 'MU', '框': 'KUANG', '类': 'LEI', '型': 'XING', '称': 'CHENG',
    '唤': 'HUAN', '符': 'FU', '教': 'JIAO', '育': 'YU', '电': 'DIAN',
    '件': 'JIAN', '食': 'SHI', '银': 'YIN', '名': 'MING',
  };

  // 2-character words - expanded list
  static final List<ChineseWord> _twoCharWords = [
    ChineseWord('学习', ['XUE', 'XI']),
    ChineseWord('工作', ['GONG', 'ZUO']),
    ChineseWord('生活', ['SHENG', 'HUO']),
    ChineseWord('时间', ['SHI', 'JIAN']),
    ChineseWord('问题', ['WEN', 'TI']),
    ChineseWord('发展', ['FA', 'ZHAN']),
    ChineseWord('经济', ['JING', 'JI']),
    ChineseWord('社会', ['SHE', 'HUI']),
    ChineseWord('文化', ['WEN', 'HUA']),
    ChineseWord('教育', ['JIAO', 'YU']),
    ChineseWord('科技', ['KE', 'JI']),
    ChineseWord('历史', ['LI', 'SHI']),
    ChineseWord('政治', ['ZHENG', 'ZHI']),
    ChineseWord('世界', ['SHI', 'JIE']),
    ChineseWord('国家', ['GUO', 'JIA']),
    ChineseWord('人民', ['REN', 'MIN']),
    ChineseWord('市场', ['SHI', 'CHANG']),
    ChineseWord('企业', ['QI', 'YE']),
    ChineseWord('管理', ['GUAN', 'LI']),
    ChineseWord('技术', ['JI', 'SHU']),
    ChineseWord('研究', ['YAN', 'JIU']),
    ChineseWord('设计', ['SHE', 'JI']),
    ChineseWord('服务', ['FU', 'WU']),
    ChineseWord('产品', ['CHAN', 'PIN']),
    ChineseWord('质量', ['ZHI', 'LIANG']),
    ChineseWord('安全', ['AN', 'QUAN']),
    ChineseWord('健康', ['JIAN', 'KANG']),
    ChineseWord('环境', ['HUAN', 'JING']),
    ChineseWord('资源', ['ZI', 'YUAN']),
    ChineseWord('能源', ['NENG', 'YUAN']),
    ChineseWord('交通', ['JIAO', 'TONG']),
    ChineseWord('通信', ['TONG', 'XIN']),
    ChineseWord('网络', ['WANG', 'LUO']),
    ChineseWord('数据', ['SHU', 'JU']),
    ChineseWord('信息', ['XIN', 'XI']),
    ChineseWord('电脑', ['DIAN', 'NAO']),
    ChineseWord('手机', ['SHOU', 'JI']),
    ChineseWord('软件', ['RUAN', 'JIAN']),
    ChineseWord('硬件', ['YING', 'JIAN']),
    ChineseWord('游戏', ['YOU', 'XI']),
    ChineseWord('音乐', ['YIN', 'YUE']),
    ChineseWord('电影', ['DIAN', 'YING']),
    ChineseWord('运动', ['YUN', 'DONG']),
    ChineseWord('旅游', ['LV', 'YOU']),
    ChineseWord('美食', ['MEI', 'SHI']),
    ChineseWord('朋友', ['PENG', 'YOU']),
    ChineseWord('家庭', ['JIA', 'TING']),
    ChineseWord('爱情', ['AI', 'QING']),
    ChineseWord('幸福', ['XING', 'FU']),
    ChineseWord('快乐', ['KUAI', 'LE']),
    ChineseWord('银行', ['YIN', 'HANG']),
    ChineseWord('行为', ['XING', 'WEI']),
    ChineseWord('长大', ['ZHANG', 'DA']),
    ChineseWord('长度', ['CHANG', 'DU']),
    ChineseWord('重要', ['ZHONG', 'YAO']),
    ChineseWord('重复', ['CHONG', 'FU']),
    ChineseWord('太阳', ['TAI', 'YANG']),
    ChineseWord('月亮', ['YUE', 'LIANG']),
    ChineseWord('星星', ['XING', 'XING']),
    ChineseWord('天空', ['TIAN', 'KONG']),
    ChineseWord('大海', ['DA', 'HAI']),
    ChineseWord('河流', ['HE', 'LIU']),
    ChineseWord('山峰', ['SHAN', 'FENG']),
    ChineseWord('森林', ['SEN', 'LIN']),
    ChineseWord('草原', ['CAO', 'YUAN']),
    ChineseWord('沙漠', ['SHA', 'MO']),
    ChineseWord('雪花', ['XUE', 'HUA']),
    ChineseWord('雨水', ['YU', 'SHUI']),
    ChineseWord('闪电', ['SHAN', 'DIAN']),
    ChineseWord('彩虹', ['CAI', 'HONG']),
    ChineseWord('云彩', ['YUN', 'CAI']),
    ChineseWord('老虎', ['LAO', 'HU']),
    ChineseWord('狮子', ['SHI', 'ZI']),
    ChineseWord('大象', ['DA', 'XIANG']),
    ChineseWord('熊猫', ['XIONG', 'MAO']),
    ChineseWord('猴子', ['HOU', 'ZI']),
    ChineseWord('兔子', ['TU', 'ZI']),
    ChineseWord('小狗', ['XIAO', 'GOU']),
    ChineseWord('小猫', ['XIAO', 'MAO']),
    ChineseWord('小鸟', ['XIAO', 'NIAO']),
    ChineseWord('金鱼', ['JIN', 'YU']),
    ChineseWord('蝴蝶', ['HU', 'DIE']),
    ChineseWord('蜜蜂', ['MI', 'FENG']),
    ChineseWord('蚂蚁', ['MA', 'YI']),
    ChineseWord('乌龟', ['WU', 'GUI']),
    ChineseWord('蜗牛', ['WO', 'NIU']),
    ChineseWord('米饭', ['MI', 'FAN']),
    ChineseWord('面条', ['MIAN', 'TIAO']),
    ChineseWord('饺子', ['JIAO', 'ZI']),
    ChineseWord('包子', ['BAO', 'ZI']),
    ChineseWord('馒头', ['MAN', 'TOU']),
    ChineseWord('豆腐', ['DOU', 'FU']),
    ChineseWord('鸡蛋', ['JI', 'DAN']),
    ChineseWord('牛奶', ['NIU', 'NAI']),
    ChineseWord('苹果', ['PING', 'GUO']),
    ChineseWord('香蕉', ['XIANG', 'JIAO']),
    ChineseWord('西瓜', ['XI', 'GUA']),
    ChineseWord('葡萄', ['PU', 'TAO']),
    ChineseWord('草莓', ['CAO', 'MEI']),
    ChineseWord('橙子', ['CHENG', 'ZI']),
    ChineseWord('柠檬', ['NING', 'MENG']),
    ChineseWord('眼睛', ['YAN', 'JING']),
    ChineseWord('耳朵', ['ER', 'DUO']),
    ChineseWord('鼻子', ['BI', 'ZI']),
    ChineseWord('嘴巴', ['ZUI', 'BA']),
    ChineseWord('头发', ['TOU', 'FA']),
    ChineseWord('手指', ['SHOU', 'ZHI']),
    ChineseWord('脚趾', ['JIAO', 'ZHI']),
    ChineseWord('心脏', ['XIN', 'ZANG']),
    ChineseWord('肚子', ['DU', 'ZI']),
    ChineseWord('肩膀', ['JIAN', 'BANG']),
    ChineseWord('早餐', ['ZAO', 'CAN']),
    ChineseWord('午餐', ['WU', 'CAN']),
    ChineseWord('晚餐', ['WAN', 'CAN']),
    ChineseWord('睡觉', ['SHUI', 'JIAO']),
    ChineseWord('起床', ['QI', 'CHUANG']),
    ChineseWord('洗澡', ['XI', 'ZAO']),
    ChineseWord('刷牙', ['SHUA', 'YA']),
    ChineseWord('穿衣', ['CHUAN', 'YI']),
    ChineseWord('吃饭', ['CHI', 'FAN']),
    ChineseWord('喝水', ['HE', 'SHUI']),
    ChineseWord('走路', ['ZOU', 'LU']),
    ChineseWord('跑步', ['PAO', 'BU']),
    ChineseWord('休息', ['XIU', 'XI']),
    ChineseWord('聊天', ['LIAO', 'TIAN']),
    ChineseWord('购物', ['GOU', 'WU']),
    ChineseWord('开心', ['KAI', 'XIN']),
    ChineseWord('难过', ['NAN', 'GUO']),
    ChineseWord('生气', ['SHENG', 'QI']),
    ChineseWord('害怕', ['HAI', 'PA']),
    ChineseWord('紧张', ['JIN', 'ZHANG']),
    ChineseWord('兴奋', ['XING', 'FEN']),
    ChineseWord('无聊', ['WU', 'LIAO']),
    ChineseWord('着急', ['ZHAO', 'JI']),
    ChineseWord('担心', ['DAN', 'XIN']),
    ChineseWord('放松', ['FANG', 'SONG']),
    ChineseWord('学校', ['XUE', 'XIAO']),
    ChineseWord('医院', ['YI', 'YUAN']),
    ChineseWord('公园', ['GONG', 'YUAN']),
    ChineseWord('超市', ['CHAO', 'SHI']),
    ChineseWord('餐厅', ['CAN', 'TING']),
    ChineseWord('机场', ['JI', 'CHANG']),
    ChineseWord('火车', ['HUO', 'CHE']),
    ChineseWord('地铁', ['DI', 'TIE']),
    ChineseWord('图书', ['TU', 'SHU']),
    ChineseWord('博物', ['BO', 'WU']),
    ChineseWord('电影', ['DIAN', 'YING']),
    ChineseWord('体育', ['TI', 'YU']),
    ChineseWord('红色', ['HONG', 'SE']),
    ChineseWord('蓝色', ['LAN', 'SE']),
    ChineseWord('绿色', ['LV', 'SE']),
    ChineseWord('黄色', ['HUANG', 'SE']),
    ChineseWord('白色', ['BAI', 'SE']),
    ChineseWord('黑色', ['HEI', 'SE']),
    ChineseWord('紫色', ['ZI', 'SE']),
    ChineseWord('粉色', ['FEN', 'SE']),
    ChineseWord('橙色', ['CHENG', 'SE']),
    ChineseWord('灰色', ['HUI', 'SE']),
    ChineseWord('爸爸', ['BA', 'BA']),
    ChineseWord('妈妈', ['MA', 'MA']),
    ChineseWord('爷爷', ['YE', 'YE']),
    ChineseWord('奶奶', ['NAI', 'NAI']),
    ChineseWord('哥哥', ['GE', 'GE']),
    ChineseWord('姐姐', ['JIE', 'JIE']),
    ChineseWord('弟弟', ['DI', 'DI']),
    ChineseWord('妹妹', ['MEI', 'MEI']),
    ChineseWord('叔叔', ['SHU', 'SHU']),
    ChineseWord('阿姨', ['A', 'YI']),
    ChineseWord('桌子', ['ZHUO', 'ZI']),
    ChineseWord('椅子', ['YI', 'ZI']),
    ChineseWord('窗户', ['CHUANG', 'HU']),
    ChineseWord('门口', ['MEN', 'KOU']),
    ChineseWord('钥匙', ['YAO', 'SHI']),
    ChineseWord('钱包', ['QIAN', 'BAO']),
    ChineseWord('雨伞', ['YU', 'SAN']),
    ChineseWord('眼镜', ['YAN', 'JING']),
    ChineseWord('手表', ['SHOU', 'BIAO']),
    ChineseWord('书包', ['SHU', 'BAO']),
    ChineseWord('铅笔', ['QIAN', 'BI']),
    ChineseWord('橡皮', ['XIANG', 'PI']),
    ChineseWord('尺子', ['CHI', 'ZI']),
    ChineseWord('剪刀', ['JIAN', 'DAO']),
    ChineseWord('胶水', ['JIAO', 'SHUI']),
    ChineseWord('看书', ['KAN', 'SHU']),
    ChineseWord('写字', ['XIE', 'ZI']),
    ChineseWord('画画', ['HUA', 'HUA']),
    ChineseWord('唱歌', ['CHANG', 'GE']),
    ChineseWord('跳舞', ['TIAO', 'WU']),
    ChineseWord('游泳', ['YOU', 'YONG']),
    ChineseWord('踢球', ['TI', 'QIU']),
    ChineseWord('打球', ['DA', 'QIU']),
    ChineseWord('开车', ['KAI', 'CHE']),
    ChineseWord('骑车', ['QI', 'CHE']),
    ChineseWord('做饭', ['ZUO', 'FAN']),
    ChineseWord('洗碗', ['XI', 'WAN']),
    ChineseWord('扫地', ['SAO', 'DI']),
    ChineseWord('拖地', ['TUO', 'DI']),
    ChineseWord('浇花', ['JIAO', 'HUA']),
    ChineseWord('晴天', ['QING', 'TIAN']),
    ChineseWord('阴天', ['YIN', 'TIAN']),
    ChineseWord('下雨', ['XIA', 'YU']),
    ChineseWord('下雪', ['XIA', 'XUE']),
    ChineseWord('刮风', ['GUA', 'FENG']),
    ChineseWord('台风', ['TAI', 'FENG']),
    ChineseWord('雷电', ['LEI', 'DIAN']),
    ChineseWord('温度', ['WEN', 'DU']),
    ChineseWord('湿度', ['SHI', 'DU']),
    ChineseWord('天气', ['TIAN', 'QI']),
    ChineseWord('明天', ['MING', 'TIAN']),
    ChineseWord('昨天', ['ZUO', 'TIAN']),
    ChineseWord('今天', ['JIN', 'TIAN']),
    ChineseWord('现在', ['XIAN', 'ZAI']),
    ChineseWord('以后', ['YI', 'HOU']),
    ChineseWord('以前', ['YI', 'QIAN']),
    ChineseWord('永远', ['YONG', 'YUAN']),
    ChineseWord('突然', ['TU', 'RAN']),
    ChineseWord('经常', ['JING', 'CHANG']),
    ChineseWord('偶尔', ['OU', 'ER']),
    ChineseWord('马上', ['MA', 'SHANG']),
    ChineseWord('刚才', ['GANG', 'CAI']),
    ChineseWord('原来', ['YUAN', 'LAI']),
    ChineseWord('终于', ['ZHONG', 'YU']),
    ChineseWord('简单', ['JIAN', 'DAN']),
    ChineseWord('复杂', ['FU', 'ZA']),
    ChineseWord('容易', ['RONG', 'YI']),
    ChineseWord('困难', ['KUN', 'NAN']),
    ChineseWord('美丽', ['MEI', 'LI']),
    ChineseWord('漂亮', ['PIAO', 'LIANG']),
    ChineseWord('帅气', ['SHUAI', 'QI']),
    ChineseWord('可爱', ['KE', 'AI']),
    ChineseWord('聪明', ['CONG', 'MING']),
    ChineseWord('勇敢', ['YONG', 'GAN']),
    ChineseWord('善良', ['SHAN', 'LIANG']),
    ChineseWord('诚实', ['CHENG', 'SHI']),
    ChineseWord('努力', ['NU', 'LI']),
    ChineseWord('认真', ['REN', 'ZHEN']),
    ChineseWord('仔细', ['ZI', 'XI']),
    ChineseWord('安静', ['AN', 'JING']),
    ChineseWord('热闹', ['RE', 'NAO']),
    ChineseWord('干净', ['GAN', 'JING']),
    ChineseWord('整齐', ['ZHENG', 'QI']),
    ChineseWord('舒服', ['SHU', 'FU']),
    ChineseWord('方便', ['FANG', 'BIAN']),
    ChineseWord('特别', ['TE', 'BIE']),
    ChineseWord('普通', ['PU', 'TONG']),
    ChineseWord('正常', ['ZHENG', 'CHANG']),
    ChineseWord('奇怪', ['QI', 'GUAI']),
    ChineseWord('有趣', ['YOU', 'QU']),
  ];

  // 4-character 成语
  static final List<ChineseWord> _fourCharIdioms = [
    ChineseWord('一心一意', ['YI', 'XIN', 'YI', 'YI']),
    ChineseWord('半途而废', ['BAN', 'TU', 'ER', 'FEI']),
    ChineseWord('不可思议', ['BU', 'KE', 'SI', 'YI']),
    ChineseWord('诚心诚意', ['CHENG', 'XIN', 'CHENG', 'YI']),
    ChineseWord('大同小异', ['DA', 'TONG', 'XIAO', 'YI']),
    ChineseWord('独一无二', ['DU', 'YI', 'WU', 'ER']),
    ChineseWord('风和日丽', ['FENG', 'HE', 'RI', 'LI']),
    ChineseWord('各有千秋', ['GE', 'YOU', 'QIAN', 'QIU']),
    ChineseWord('好事多磨', ['HAO', 'SHI', 'DUO', 'MO']),
    ChineseWord('画龙点睛', ['HUA', 'LONG', 'DIAN', 'JING']),
    ChineseWord('急中生智', ['JI', 'ZHONG', 'SHENG', 'ZHI']),
    ChineseWord('见义勇为', ['JIAN', 'YI', 'YONG', 'WEI']),
    ChineseWord('精益求精', ['JING', 'YI', 'QIU', 'JING']),
    ChineseWord('开天辟地', ['KAI', 'TIAN', 'PI', 'DI']),
    ChineseWord('乐在其中', ['LE', 'ZAI', 'QI', 'ZHONG']),
    ChineseWord('龙飞凤舞', ['LONG', 'FEI', 'FENG', 'WU']),
    ChineseWord('名副其实', ['MING', 'FU', 'QI', 'SHI']),
    ChineseWord('宁死不屈', ['NING', 'SI', 'BU', 'QU']),
    ChineseWord('破釜沉舟', ['PO', 'FU', 'CHEN', 'ZHOU']),
    ChineseWord('千方百计', ['QIAN', 'FANG', 'BAI', 'JI']),
    ChineseWord('全心全意', ['QUAN', 'XIN', 'QUAN', 'YI']),
    ChineseWord('人山人海', ['REN', 'SHAN', 'REN', 'HAI']),
    ChineseWord('三心二意', ['SAN', 'XIN', 'ER', 'YI']),
    ChineseWord('水落石出', ['SHUI', 'LUO', 'SHI', 'CHU']),
    ChineseWord('天长地久', ['TIAN', 'CHANG', 'DI', 'JIU']),
    ChineseWord('万众一心', ['WAN', 'ZHONG', 'YI', 'XIN']),
    ChineseWord('心想事成', ['XIN', 'XIANG', 'SHI', 'CHENG']),
    ChineseWord('学以致用', ['XUE', 'YI', 'ZHI', 'YONG']),
    ChineseWord('一举两得', ['YI', 'JU', 'LIANG', 'DE']),
    ChineseWord('自由自在', ['ZI', 'YOU', 'ZI', 'ZAI']),
    ChineseWord('脚踏实地', ['JIAO', 'TA', 'SHI', 'DI']),
    ChineseWord('实事求是', ['SHI', 'SHI', 'QIU', 'SHI']),
    ChineseWord('守株待兔', ['SHOU', 'ZHU', 'DAI', 'TU']),
    ChineseWord('狐假虎威', ['HU', 'JIA', 'HU', 'WEI']),
    ChineseWord('画蛇添足', ['HUA', 'SHE', 'TIAN', 'ZU']),
    ChineseWord('刻舟求剑', ['KE', 'ZHOU', 'QIU', 'JIAN']),
    ChineseWord('井底之蛙', ['JING', 'DI', 'ZHI', 'WA']),
    ChineseWord('掩耳盗铃', ['YAN', 'ER', 'DAO', 'LING']),
    ChineseWord('叶公好龙', ['YE', 'GONG', 'HAO', 'LONG']),
    ChineseWord('自相矛盾', ['ZI', 'XIANG', 'MAO', 'DUN']),
    ChineseWord('一马当先', ['YI', 'MA', 'DANG', 'XIAN']),
    ChineseWord('一鸣惊人', ['YI', 'MING', 'JING', 'REN']),
    ChineseWord('一石二鸟', ['YI', 'SHI', 'ER', 'NIAO']),
    ChineseWord('一箭双雕', ['YI', 'JIAN', 'SHUANG', 'DIAO']),
    ChineseWord('一帆风顺', ['YI', 'FAN', 'FENG', 'SHUN']),
    ChineseWord('一鼓作气', ['YI', 'GU', 'ZUO', 'QI']),
    ChineseWord('一见钟情', ['YI', 'JIAN', 'ZHONG', 'QING']),
    ChineseWord('一路平安', ['YI', 'LU', 'PING', 'AN']),
    ChineseWord('一目了然', ['YI', 'MU', 'LIAO', 'RAN']),
    ChineseWord('一视同仁', ['YI', 'SHI', 'TONG', 'REN']),
    ChineseWord('七上八下', ['QI', 'SHANG', 'BA', 'XIA']),
    ChineseWord('三言两语', ['SAN', 'YAN', 'LIANG', 'YU']),
    ChineseWord('不求甚解', ['BU', 'QIU', 'SHEN', 'JIE']),
    ChineseWord('不知不觉', ['BU', 'ZHI', 'BU', 'JUE']),
    ChineseWord('不折不扣', ['BU', 'ZHE', 'BU', 'KOU']),
    ChineseWord('不约而同', ['BU', 'YUE', 'ER', 'TONG']),
    ChineseWord('专心致志', ['ZHUAN', 'XIN', 'ZHI', 'ZHI']),
    ChineseWord('世外桃源', ['SHI', 'WAI', 'TAO', 'YUAN']),
    ChineseWord('东张西望', ['DONG', 'ZHANG', 'XI', 'WANG']),
    ChineseWord('两全其美', ['LIANG', 'QUAN', 'QI', 'MEI']),
    ChineseWord('五花八门', ['WU', 'HUA', 'BA', 'MEN']),
    ChineseWord('五颜六色', ['WU', 'YAN', 'LIU', 'SE']),
    ChineseWord('亡羊补牢', ['WANG', 'YANG', 'BU', 'LAO']),
    ChineseWord('以身作则', ['YI', 'SHEN', 'ZUO', 'ZE']),
    ChineseWord('众志成城', ['ZHONG', 'ZHI', 'CHENG', 'CHENG']),
    ChineseWord('先发制人', ['XIAN', 'FA', 'ZHI', 'REN']),
    ChineseWord('兴高采烈', ['XING', 'GAO', 'CAI', 'LIE']),
    ChineseWord('出类拔萃', ['CHU', 'LEI', 'BA', 'CUI']),
    ChineseWord('刻骨铭心', ['KE', 'GU', 'MING', 'XIN']),
    ChineseWord('前仆后继', ['QIAN', 'PU', 'HOU', 'JI']),
    ChineseWord('助人为乐', ['ZHU', 'REN', 'WEI', 'LE']),
    ChineseWord('千载难逢', ['QIAN', 'ZAI', 'NAN', 'FENG']),
    ChineseWord('千锤百炼', ['QIAN', 'CHUI', 'BAI', 'LIAN']),
    ChineseWord('博大精深', ['BO', 'DA', 'JING', 'SHEN']),
    ChineseWord('取长补短', ['QU', 'CHANG', 'BU', 'DUAN']),
    ChineseWord('坚持不懈', ['JIAN', 'CHI', 'BU', 'XIE']),
    ChineseWord('夜以继日', ['YE', 'YI', 'JI', 'RI']),
    ChineseWord('大公无私', ['DA', 'GONG', 'WU', 'SI']),
    ChineseWord('大显身手', ['DA', 'XIAN', 'SHEN', 'SHOU']),
    ChineseWord('天衣无缝', ['TIAN', 'YI', 'WU', 'FENG']),
    ChineseWord('如虎添翼', ['RU', 'HU', 'TIAN', 'YI']),
    ChineseWord('如鱼得水', ['RU', 'YU', 'DE', 'SHUI']),
    ChineseWord('对症下药', ['DUI', 'ZHENG', 'XIA', 'YAO']),
    ChineseWord('异想天开', ['YI', 'XIANG', 'TIAN', 'KAI']),
    ChineseWord('当机立断', ['DANG', 'JI', 'LI', 'DUAN']),
    ChineseWord('恍然大悟', ['HUANG', 'RAN', 'DA', 'WU']),
    ChineseWord('情不自禁', ['QING', 'BU', 'ZI', 'JIN']),
    ChineseWord('成语故事', ['CHENG', 'YU', 'GU', 'SHI']),
    ChineseWord('手忙脚乱', ['SHOU', 'MANG', 'JIAO', 'LUAN']),
    ChineseWord('持之以恒', ['CHI', 'ZHI', 'YI', 'HENG']),
    ChineseWord('推陈出新', ['TUI', 'CHEN', 'CHU', 'XIN']),
    ChineseWord('斗志昂扬', ['DOU', 'ZHI', 'ANG', 'YANG']),
    ChineseWord('有备无患', ['YOU', 'BEI', 'WU', 'HUAN']),
    ChineseWord('有条不紊', ['YOU', 'TIAO', 'BU', 'WEN']),
    ChineseWord('望梅止渴', ['WANG', 'MEI', 'ZHI', 'KE']),
    ChineseWord('杯水车薪', ['BEI', 'SHUI', 'CHE', 'XIN']),
    ChineseWord('机不可失', ['JI', 'BU', 'KE', 'SHI']),
    ChineseWord('栩栩如生', ['XU', 'XU', 'RU', 'SHENG']),
    ChineseWord('欣欣向荣', ['XIN', 'XIN', 'XIANG', 'RONG']),
    ChineseWord('津津有味', ['JIN', 'JIN', 'YOU', 'WEI']),
    ChineseWord('洋洋洒洒', ['YANG', 'YANG', 'SA', 'SA']),
    ChineseWord('海阔天空', ['HAI', 'KUO', 'TIAN', 'KONG']),
    ChineseWord('温故知新', ['WEN', 'GU', 'ZHI', 'XIN']),
    ChineseWord('滴水穿石', ['DI', 'SHUI', 'CHUAN', 'SHI']),
    ChineseWord('熟能生巧', ['SHU', 'NENG', 'SHENG', 'QIAO']),
    ChineseWord('物极必反', ['WU', 'JI', 'BI', 'FAN']),
    ChineseWord('百发百中', ['BAI', 'FA', 'BAI', 'ZHONG']),
    ChineseWord('百折不挠', ['BAI', 'ZHE', 'BU', 'NAO']),
    ChineseWord('眉开眼笑', ['MEI', 'KAI', 'YAN', 'XIAO']),
    ChineseWord('知己知彼', ['ZHI', 'JI', 'ZHI', 'BI']),
    ChineseWord('见多识广', ['JIAN', 'DUO', 'SHI', 'GUANG']),
    ChineseWord('言行一致', ['YAN', 'XING', 'YI', 'ZHI']),
    ChineseWord('迎难而上', ['YING', 'NAN', 'ER', 'SHANG']),
    ChineseWord('随机应变', ['SUI', 'JI', 'YING', 'BIAN']),
    ChineseWord('雪中送炭', ['XUE', 'ZHONG', 'SONG', 'TAN']),
    ChineseWord('风雨同舟', ['FENG', 'YU', 'TONG', 'ZHOU']),
    ChineseWord('马到成功', ['MA', 'DAO', 'CHENG', 'GONG']),
    ChineseWord('鹤立鸡群', ['HE', 'LI', 'JI', 'QUN']),
  ];

  static List<ChineseWord> _getWordsByLength(int length) {
    switch (length) {
      case 2:
        return _twoCharWords;
      case 4:
        return _fourCharIdioms;
      default:
        return _twoCharWords;
    }
  }

  ChineseWord getRandomWord({int length = 2}) {
    final words = _getWordsByLength(length);
    final random = Random();
    final availableWords = words.where((w) => !_usedWords.contains(w.characters)).toList();
    if (availableWords.isEmpty) {
      _usedWords.clear();
      final word = words[random.nextInt(words.length)];
      _usedWords.add(word.characters);
      return word;
    }
    final word = availableWords[random.nextInt(availableWords.length)];
    _usedWords.add(word.characters);
    return word;
  }

  List<String> getPinyinOptions(String character) {
    if (_polyphonicChars.containsKey(character)) {
      return _polyphonicChars[character]!
          .map((p) => _normalizePinyin(p))
          .toList();
    }
    return [];
  }

  bool isPolyphonic(String character) {
    return _polyphonicChars.containsKey(character);
  }

  /// Look up pinyin for Chinese characters
  /// Fallback chain: Proxy (OpenAI) → built-in character map
  /// MDBG removed — API is dead and caused routing bugs
  Future<List<String>?> lookupPinyin(String characters) async {
    // Check cache first
    if (_pinyinCache.containsKey(characters)) {
      return _pinyinCache[characters];
    }

    // Try Cloudflare Worker proxy (OpenAI) first
    if (hasProxy) {
      final proxyResult = await _lookupPinyinFromProxy(characters);
      if (proxyResult != null) {
        _pinyinCache[characters] = proxyResult;
        return proxyResult;
      }
    }

    // Fallback: built-in character map
    final result = _lookupFromBuiltIn(characters);
    if (result != null) {
      _pinyinCache[characters] = result;
      return result;
    }

    print('[DictionaryService] All pinyin lookups failed for "$characters"');
    return null;
  }

  List<String>? _lookupFromBuiltIn(String characters) {
    final result = <String>[];
    for (int i = 0; i < characters.length; i++) {
      final char = characters[i];
      String? pinyin;

      if (_singleCharPinyin.containsKey(char)) {
        pinyin = _singleCharPinyin[char];
      }

      if (pinyin == null) {
        for (var word in [..._twoCharWords, ..._fourCharIdioms]) {
          final idx = word.characters.indexOf(char);
          if (idx >= 0) {
            pinyin = word.pinyinList[idx];
            break;
          }
        }
      }

      if (pinyin == null && _polyphonicChars.containsKey(char)) {
        pinyin = _normalizePinyin(_polyphonicChars[char]!.first);
      }

      if (pinyin == null) return null;
      result.add(pinyin);
    }
    return result;
  }

  String _normalizePinyin(String pinyin) {
    const toneMap = {
      'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
      'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
      'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
      'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
      'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
      'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v',
      'ü': 'v',
    };

    String normalized = pinyin
        .replaceAllMapped(RegExp(r'[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛÜ]'), (match) {
          final char = match.group(0)!.toLowerCase();
          return toneMap[char] ?? char;
        })
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase();

    return normalized;
  }

  Future<ChineseWord?> createWord(String characters) async {
    if (characters.length < 2 || characters.length > 8) return null;

    final pinyinList = await lookupPinyin(characters);
    if (pinyinList == null || pinyinList.length != characters.length) {
      return null;
    }

    return ChineseWord(characters, pinyinList);
  }

  Set<String> getCandidatesForPinyin(String pinyin) {
    final candidates = <String>{};
    final upperPinyin = pinyin.toUpperCase();

    for (var word in [..._twoCharWords, ..._fourCharIdioms]) {
      for (int i = 0; i < word.pinyinList.length; i++) {
        if (word.pinyinList[i] == upperPinyin) {
          candidates.add(word.characters[i]);
        }
      }
    }

    return candidates;
  }

  List<int> getAvailableWordLengths() {
    return [2, 4];
  }

  Future<ChineseWord?> fetchRandomWord({int length = 2}) async {
    if (!hasProxy) {
      return getRandomWord(length: length);
    }

    final recentWords = _usedWords.take(20).toList();

    try {
      final response = await http.post(
        Uri.parse('$_proxyUrl/random-word'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'length': length,
          'exclude': recentWords,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['word'] as String?;
        if (content != null) {
          final chineseOnly = content.replaceAll(RegExp(r'[^\u4e00-\u9fff]'), '');
          if (chineseOnly.length == length && !_usedWords.contains(chineseOnly)) {
            final word = await createWord(chineseOnly);
            if (word != null) {
              _usedWords.add(chineseOnly);
              return word;
            }
          }
        }
      }
    } catch (e) {
      // Fall back to hardcoded list
    }

    return getRandomWord(length: length);
  }

  final Map<String, List<String>> _hintsCache = {};

  int getPinyinLetterCount(List<String> pinyinList) {
    return pinyinList.fold(0, (sum, pinyin) => sum + pinyin.length);
  }

  Future<List<String>?> getAllHints(String characters, {bool isIdiom = false}) async {
    if (!hasProxy) return null;

    if (_hintsCache.containsKey(characters)) {
      return _hintsCache[characters];
    }

    try {
      final response = await http.post(
        Uri.parse('$_proxyUrl/hints'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'characters': characters,
          'isIdiom': isIdiom,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hintsData = data['hints'];
        if (hintsData != null && hintsData is List && hintsData.length >= 3) {
          final hints = hintsData.take(3).map((h) => h.toString()).toList();
          _hintsCache[characters] = hints;
          return hints;
        }
      }
    } catch (e) {
      // Failed to get hints
    }
    return null;
  }

  Future<String?> getWordHint(String characters, {int level = 1, bool isIdiom = false}) async {
    final allHints = await getAllHints(characters, isIdiom: isIdiom);
    if (allHints != null && level >= 1 && level <= allHints.length) {
      return allHints[level - 1];
    }
    return null;
  }

  Future<bool> verifyWord(String characters) async {
    final pinyin = await lookupPinyin(characters);
    return pinyin != null && pinyin.length == characters.length;
  }
}