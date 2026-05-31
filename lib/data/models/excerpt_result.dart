class ExcerptResult {
  final List<String> impactPhrases;
  final List<String> shortPosts;
  final List<String> carouselIdeas;
  final List<String> videoScripts;
  final String purchaseCta;
  final String followCta;

  const ExcerptResult({
    required this.impactPhrases,
    required this.shortPosts,
    required this.carouselIdeas,
    required this.videoScripts,
    required this.purchaseCta,
    required this.followCta,
  });

  factory ExcerptResult.fromMap(Map<String, dynamic> m) => ExcerptResult(
        impactPhrases: _toList(m['impact_phrases']),
        shortPosts: _toList(m['short_posts']),
        carouselIdeas: _toList(m['carousel_ideas']),
        videoScripts: _toList(m['video_scripts']),
        purchaseCta: m['purchase_cta'] as String? ?? '',
        followCta: m['follow_cta'] as String? ?? '',
      );

  static List<String> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.cast<String>();
    return [];
  }
}

class RepurposedContent {
  final List<String> instagramPosts;
  final List<Map<String, dynamic>> carousels;
  final List<String> reelsScripts;
  final String blogArticle;
  final String email;
  final List<String> alternativeTitles;

  const RepurposedContent({
    required this.instagramPosts,
    required this.carousels,
    required this.reelsScripts,
    required this.blogArticle,
    required this.email,
    required this.alternativeTitles,
  });

  factory RepurposedContent.fromMap(Map<String, dynamic> m) => RepurposedContent(
        instagramPosts: _toList(m['instagram_posts']),
        carousels: _toMapList(m['carousels']),
        reelsScripts: _toList(m['reels_scripts']),
        blogArticle: m['blog_article'] as String? ?? '',
        email: m['email'] as String? ?? '',
        alternativeTitles: _toList(m['alternative_titles']),
      );

  static List<String> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.cast<String>();
    return [];
  }

  static List<Map<String, dynamic>> _toMapList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.cast<Map<String, dynamic>>();
    return [];
  }
}

class CalendarDay {
  final int day;
  final String theme;
  final String format;
  final String hook;
  final String cta;
  final String strategicNote;

  const CalendarDay({
    required this.day,
    required this.theme,
    required this.format,
    required this.hook,
    required this.cta,
    required this.strategicNote,
  });

  factory CalendarDay.fromMap(Map<String, dynamic> m) => CalendarDay(
        day: (m['day'] as num?)?.toInt() ?? 0,
        theme: m['theme'] as String? ?? '',
        format: m['format'] as String? ?? '',
        hook: m['hook'] as String? ?? '',
        cta: m['cta'] as String? ?? '',
        strategicNote: m['strategic_note'] as String? ?? '',
      );
}

class CalendarPlan {
  final List<CalendarDay> days;
  final String brandName;
  final String objective;
  final String platform;
  final int periodDays;

  const CalendarPlan({
    required this.days,
    required this.brandName,
    required this.objective,
    required this.platform,
    required this.periodDays,
  });

  factory CalendarPlan.fromMap(Map<String, dynamic> m) => CalendarPlan(
        days: (m['days'] as List?)
                ?.map((e) => CalendarDay.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        brandName: m['brand_name'] as String? ?? '',
        objective: m['objective'] as String? ?? '',
        platform: m['platform'] as String? ?? '',
        periodDays: (m['period_days'] as num?)?.toInt() ?? 7,
      );
}
