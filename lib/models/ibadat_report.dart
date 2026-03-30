class IbadatReport {
  final String? id;
  final String userId;
  final String groupId;
  final int month;
  final int year;
  int quranPages;
  int bookPages;
  int jawshanCount;
  int fastingDays;
  int risalePages;
  int audioMinutes;
  int salawatCount;
  int istighfarCount;
  int tahajjudCount;
  int zikirCount;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  IbadatReport({
    this.id,
    required this.userId,
    required this.groupId,
    required this.month,
    required this.year,
    this.quranPages = 0,
    this.bookPages = 0,
    this.jawshanCount = 0,
    this.fastingDays = 0,
    this.risalePages = 0,
    this.audioMinutes = 0,
    this.salawatCount = 0,
    this.istighfarCount = 0,
    this.tahajjudCount = 0,
    this.zikirCount = 0,
    this.submittedAt,
    this.updatedAt,
  });

  factory IbadatReport.fromJson(Map<String, dynamic> json) {
    return IbadatReport(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      groupId: json['group_id'] as String,
      month: json['month'] as int,
      year: json['year'] as int,
      quranPages: json['quran_pages'] as int? ?? 0,
      bookPages: json['book_pages'] as int? ?? 0,
      jawshanCount: json['jawshan_count'] as int? ?? 0,
      fastingDays: json['fasting_days'] as int? ?? 0,
      risalePages: json['risale_pages'] as int? ?? 0,
      audioMinutes: json['audio_minutes'] as int? ?? 0,
      salawatCount: json['salawat_count'] as int? ?? 0,
      istighfarCount: json['istighfar_count'] as int? ?? 0,
      tahajjudCount: json['tahajjud_count'] as int? ?? 0,
      zikirCount: json['zikir_count'] as int? ?? 0,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'group_id': groupId,
      'month': month,
      'year': year,
      'quran_pages': quranPages,
      'book_pages': bookPages,
      'jawshan_count': jawshanCount,
      'fasting_days': fastingDays,
      'risale_pages': risalePages,
      'audio_minutes': audioMinutes,
      'salawat_count': salawatCount,
      'istighfar_count': istighfarCount,
      'tahajjud_count': tahajjudCount,
      'zikir_count': zikirCount,
    };
  }

  /// Returns value for a given category key
  int getValue(String key) {
    switch (key) {
      case 'quran_pages':    return quranPages;
      case 'book_pages':     return bookPages;
      case 'jawshan_count':  return jawshanCount;
      case 'fasting_days':   return fastingDays;
      case 'risale_pages':   return risalePages;
      case 'audio_minutes':  return audioMinutes;
      case 'salawat_count':  return salawatCount;
      case 'istighfar_count': return istighfarCount;
      case 'tahajjud_count':  return tahajjudCount;
      case 'zikir_count':     return zikirCount;
      default: return 0;
    }
  }

  void setValue(String key, int value) {
    switch (key) {
      case 'quran_pages':    quranPages = value; break;
      case 'book_pages':     bookPages = value; break;
      case 'jawshan_count':  jawshanCount = value; break;
      case 'fasting_days':   fastingDays = value; break;
      case 'risale_pages':   risalePages = value; break;
      case 'audio_minutes':  audioMinutes = value; break;
      case 'salawat_count':  salawatCount = value; break;
      case 'istighfar_count': istighfarCount = value; break;
      case 'tahajjud_count':  tahajjudCount = value; break;
      case 'zikir_count':     zikirCount = value; break;
    }
  }

  IbadatReport copyWith() {
    return IbadatReport(
      id: id,
      userId: userId,
      groupId: groupId,
      month: month,
      year: year,
      quranPages: quranPages,
      bookPages: bookPages,
      jawshanCount: jawshanCount,
      fastingDays: fastingDays,
      risalePages: risalePages,
      audioMinutes: audioMinutes,
      salawatCount: salawatCount,
      istighfarCount: istighfarCount,
      tahajjudCount: tahajjudCount,
      zikirCount: zikirCount,
      submittedAt: submittedAt,
      updatedAt: updatedAt,
    );
  }
}
