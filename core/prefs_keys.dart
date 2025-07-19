class PrefsKeys {
  static const lastDate = 'last_date_yyyyMMdd';
  static const zikrCount = 'zikr_count';
  static String taskKey(String name) => 'task_${name.replaceAll(" ", "_")}';
  static const zikrSelectedPhrase = 'zikr_selected_phrase';
  static const zikrTarget = 'zikr_target';
  static const zikrHaptics = 'zikr_haptics';
  static const zikrTodayHistory = 'zikr_today_history'; // JSON map phrase->count
  static const zikrSessionCount = 'zikr_session_count'; // per selected phrase

}
