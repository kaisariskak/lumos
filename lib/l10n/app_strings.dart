import 'package:flutter/material.dart';

class AppStrings {
  final String languageCode;

  // ── General ────────────────────────────────────────────
  final String appTitle;
  final String back;
  final String cancel;
  final String yes;
  final String no;
  final String save;
  final String add;
  final String delete;
  final String remove;
  final String error;
  final String loading;
  final String close;
  final String codeCopied;
  final String retry;

  // ── Auth ───────────────────────────────────────────────
  final String appSubtitle;
  final String signInGoogle;
  final String signingIn;
  final String noPassword;
  final String notRegistered;
  final String appLocked;
  final String unlock;
  final String switchAccount;
  final String accessDenied;
  final String notAllowedDesc;
  final String profileNotLoaded;

  // ── Group Picker ───────────────────────────────────────
  final String selectGroup;
  final String groupSubtitle;
  final String availableGroups;
  final String noGroupsHint;
  final String currentLabel;
  final String createNewGroup;
  final String groupNameHint;
  final String create;
  final String creating;

  // ── Main Scaffold ──────────────────────────────────────
  final String tabList;
  final String tabReport;
  final String tabAdmin;
  final String tabCodes;
  final String tabProfile;
  final String tabPayments;
  final String allGroups;
  final String noGroupSelected;
  final String selectGroupBtn;
  final String logout;

  // ── Profile ────────────────────────────────────────────
  final String groupLabel;
  final String language;
  final String colorTheme;
  final String kazakh;
  final String russian;

  // ── Admin ──────────────────────────────────────────────
  final String adminTitle;
  final String superAdminLabel;
  final String groupAdminLabel;
  final String memberCount;
  final String noMembers;
  final String codeLabel;
  final String deleteGroup;
  final String deleteGroupConfirm;
  final String removeAdmin;
  final String makeAdmin;
  final String removeFinancier;
  final String makeFinancier;
  final String financierRemoved;
  final String financierAssigned;
  final String changeGroup;
  final String removeMember;
  final String removeMemberConfirm;
  final String noOtherGroups;
  final String selectNewGroup;
  final String addUser;
  final String emailHint;
  final String groupNameLabel;
  final String startDateOptional;
  final String selectStartDate;
  final String groupCreated;
  final String userAdded;
  final String userAutoJoin;
  final String userAlreadyInGroup;
  final String userInOtherGroup;
  final String removedFromGroup;
  final String adminRemoved;
  final String adminAssigned;
  final String updateFailed;
  final String addFailed;
  final String myAdminsTitle;
  final String noAdmins;
  final String addAdminHint;
  final String ungroupedUsers;
  final String ungroupedUsersDesc;
  final String maxValuesTitle;
  final String maxValuesHint;
  final String periodHasReports;

  // ── Periods ────────────────────────────────────────────
  final String periods;
  final String noPeriods;
  final String createPeriod;
  final String periodStart;
  final String periodEnd;
  final String periodCreated;
  final String selectDate;
  final String allowlist;
  final String allowedEmails;
  final String noAllowedEmails;
  final String addEmail;
  final String emailLabel;
  final String removeFromList;

  // ── Payments ──────────────────────────────────────────
  final String financierLabel;
  final String paymentsTitle;
  final String allMembers;
  final String thisMonth;
  final String total;
  final String paidLabel;
  final String unpaidLabel;
  final String noPayments;
  final String addPayment;
  final String editPayment;
  final String amountLabel;
  final String paymentDate;
  final String selectPaymentDate;
  final String monthlyPayment;
  final String extraPayment;
  final String paidStatus;
  final String unpaidStatus;
  final String extraLabel;
  final String monthlyLabel;
  final String allPaymentsLabel;
  final String timesUnit;
  final String deletePaymentConfirm;
  final String switchGroupTitle;
  final String fixedMonthlyAmount;
  final String fixedAmountHint;
  final String fixedAmountLabel;
  final String partiallyPaidLabel;
  final String partiallyPaidStatus;
  final String editFixedAmount;

  // ── Home / Report ──────────────────────────────────────
  final String weekLabel;
  final String monthLabel;
  final String noReport;
  final String myReport;
  final String allReports;
  final String viewDetail;
  final String reportSaved;
  final String reportSaving;

  // ── Waiting screen ─────────────────────────────────────
  final String waitingForGroup;
  final String waitingDesc;

  // ── Invite Code ────────────────────────────────────────
  final String inviteCodeTitle;
  final String inviteCodeSubtitle;
  final String inviteCodeCheck;
  final String inviteCodeNotFound;
  final String inviteCodeExpired;
  final String inviteCodeUsed;
  final String generateAdminCode;
  final String generateUserCode;
  final String activeCode;
  final String noActiveCode;
  final String codeExpiresIn;

  // ── Home (extra) ───────────────────────────────────────
  final String greeting;
  final String switchGroupShort;
  final String noPeriodSelected;
  final String autoCalculated;

  // ── Progress / Milestones ──────────────────────────────
  final String milestoneStart;
  final String milestoneKeepGoing;
  final String milestoneHalfWay;
  final String milestoneGoodProgress;
  final String milestoneExcellent;
  final String groupProgress;
  final String perWeek;
  final String paymentUnit;
  final String youLabel;
  final String membersTitle;
  final String memberRoleLabel;
  final String currentWeekLabel;
  final String weeksAgoSuffix;

  // ── PIN ────────────────────────────────────────────────
  final String pinCode;
  final String pinEnabled;
  final String pinDisabled;
  final String pinSetup;
  final String pinChange;
  final String pinDisable;
  final String pinEnter;
  final String pinNewCode;
  final String pinConfirm;
  final String pinWrong;
  final String pinMismatch;

  const AppStrings({
    required this.languageCode,
    required this.appTitle,
    required this.back,
    required this.cancel,
    required this.yes,
    required this.no,
    required this.save,
    required this.add,
    required this.delete,
    required this.remove,
    required this.error,
    required this.loading,
    required this.close,
    required this.codeCopied,
    required this.retry,
    required this.appSubtitle,
    required this.signInGoogle,
    required this.signingIn,
    required this.noPassword,
    required this.notRegistered,
    required this.appLocked,
    required this.unlock,
    required this.switchAccount,
    required this.accessDenied,
    required this.notAllowedDesc,
    required this.profileNotLoaded,
    required this.selectGroup,
    required this.groupSubtitle,
    required this.availableGroups,
    required this.noGroupsHint,
    required this.currentLabel,
    required this.createNewGroup,
    required this.groupNameHint,
    required this.create,
    required this.creating,
    required this.tabList,
    required this.tabReport,
    required this.tabAdmin,
    required this.tabCodes,
    required this.tabProfile,
    required this.tabPayments,
    required this.allGroups,
    required this.noGroupSelected,
    required this.selectGroupBtn,
    required this.logout,
    required this.groupLabel,
    required this.language,
    required this.colorTheme,
    required this.kazakh,
    required this.russian,
    required this.adminTitle,
    required this.superAdminLabel,
    required this.groupAdminLabel,
    required this.memberCount,
    required this.noMembers,
    required this.codeLabel,
    required this.deleteGroup,
    required this.deleteGroupConfirm,
    required this.removeAdmin,
    required this.makeAdmin,
    required this.removeFinancier,
    required this.makeFinancier,
    required this.financierRemoved,
    required this.financierAssigned,
    required this.changeGroup,
    required this.removeMember,
    required this.removeMemberConfirm,
    required this.noOtherGroups,
    required this.selectNewGroup,
    required this.addUser,
    required this.emailHint,
    required this.groupNameLabel,
    required this.startDateOptional,
    required this.selectStartDate,
    required this.groupCreated,
    required this.userAdded,
    required this.userAutoJoin,
    required this.userAlreadyInGroup,
    required this.userInOtherGroup,
    required this.removedFromGroup,
    required this.adminRemoved,
    required this.adminAssigned,
    required this.updateFailed,
    required this.addFailed,
    required this.myAdminsTitle,
    required this.noAdmins,
    required this.addAdminHint,
    required this.ungroupedUsers,
    required this.ungroupedUsersDesc,
    required this.maxValuesTitle,
    required this.maxValuesHint,
    required this.periodHasReports,
    required this.periods,
    required this.noPeriods,
    required this.createPeriod,
    required this.periodStart,
    required this.periodEnd,
    required this.periodCreated,
    required this.selectDate,
    required this.allowlist,
    required this.allowedEmails,
    required this.noAllowedEmails,
    required this.addEmail,
    required this.emailLabel,
    required this.removeFromList,
    required this.financierLabel,
    required this.paymentsTitle,
    required this.allMembers,
    required this.thisMonth,
    required this.total,
    required this.paidLabel,
    required this.unpaidLabel,
    required this.noPayments,
    required this.addPayment,
    required this.editPayment,
    required this.amountLabel,
    required this.paymentDate,
    required this.selectPaymentDate,
    required this.monthlyPayment,
    required this.extraPayment,
    required this.paidStatus,
    required this.unpaidStatus,
    required this.extraLabel,
    required this.monthlyLabel,
    required this.allPaymentsLabel,
    required this.timesUnit,
    required this.deletePaymentConfirm,
    required this.switchGroupTitle,
    required this.fixedMonthlyAmount,
    required this.fixedAmountHint,
    required this.fixedAmountLabel,
    required this.partiallyPaidLabel,
    required this.partiallyPaidStatus,
    required this.editFixedAmount,
    required this.weekLabel,
    required this.monthLabel,
    required this.noReport,
    required this.myReport,
    required this.allReports,
    required this.viewDetail,
    required this.reportSaved,
    required this.reportSaving,
    required this.waitingForGroup,
    required this.waitingDesc,
    required this.inviteCodeTitle,
    required this.inviteCodeSubtitle,
    required this.inviteCodeCheck,
    required this.inviteCodeNotFound,
    required this.inviteCodeExpired,
    required this.inviteCodeUsed,
    required this.generateAdminCode,
    required this.generateUserCode,
    required this.activeCode,
    required this.noActiveCode,
    required this.codeExpiresIn,
    required this.greeting,
    required this.switchGroupShort,
    required this.noPeriodSelected,
    required this.autoCalculated,
    required this.milestoneStart,
    required this.milestoneKeepGoing,
    required this.milestoneHalfWay,
    required this.milestoneGoodProgress,
    required this.milestoneExcellent,
    required this.groupProgress,
    required this.perWeek,
    required this.paymentUnit,
    required this.youLabel,
    required this.membersTitle,
    required this.memberRoleLabel,
    required this.currentWeekLabel,
    required this.weeksAgoSuffix,
    required this.pinCode,
    required this.pinEnabled,
    required this.pinDisabled,
    required this.pinSetup,
    required this.pinChange,
    required this.pinDisable,
    required this.pinEnter,
    required this.pinNewCode,
    required this.pinConfirm,
    required this.pinWrong,
    required this.pinMismatch,
  });
}

// ── Kazakh strings ─────────────────────────────────────────────────────────

const _kk = AppStrings(
  languageCode: 'kk',
  appTitle: 'Ибадат Трекер',
  back: 'Артқа',
  cancel: 'Болдырмау',
  yes: 'Иә',
  no: 'Жоқ',
  save: 'Сақтау',
  add: 'Қосу',
  delete: 'Жою',
  remove: 'Шығару',
  error: 'Қате',
  loading: 'Жүктелуде...',
  close: 'Жабу',
  codeCopied: 'Код көшірілді',
  retry: 'Қайталау',

  appSubtitle: 'Апталық ибадатыңызды жүргізіңіз',
  signInGoogle: 'Google арқылы кіру',
  signingIn: 'Кіруде...',
  noPassword: 'Құпиясөз қажет емес',
  notRegistered: 'Сіз жүйеде тіркелмегенсіз. Администраторға хабарласыңыз.',
  appLocked: 'Қолданба бұғатталды',
  unlock: 'Ашу',
  switchAccount: 'Басқа аккаунтпен кіру',
  accessDenied: 'Жүйеге кіру мүмкін емес',
  notAllowedDesc: 'Сізді әлі администратор жүйеге тіркемеген. Администраторға хабарласыңыз.',
  profileNotLoaded: 'Профиль жүктелмеді',

  selectGroup: 'Топты таңдаңыз',
  groupSubtitle: 'Ибадатыңызды бірге жүргізіңіз',
  availableGroups: 'Қолданыстағы топтар',
  noGroupsHint: 'Топ жоқ. Жаңа топ құрыңыз',
  currentLabel: 'Ағымдағы',
  createNewGroup: '✨ Жаңа топ құру',
  groupNameHint: 'Топ атауы...',
  create: 'Құру',
  creating: 'Құрылуда...',

  tabList: 'Тізім',
  tabReport: 'Есебім',
  tabAdmin: 'Админ',
  tabCodes: 'Кодтар',
  tabProfile: 'Профиль',
  tabPayments: 'Төлем',
  allGroups: 'Барлық топтар',
  noGroupSelected: 'Топ таңдалмаған',
  selectGroupBtn: 'Топ таңдау',
  logout: 'Шығу',

  groupLabel: 'Топ',
  language: 'Тіл',
  colorTheme: 'Түс тақырыбы',
  kazakh: 'Қазақша',
  russian: 'Русский',

  adminTitle: 'Басқару',
  superAdminLabel: 'Супер Админ',
  groupAdminLabel: 'Топ Админ',
  memberCount: 'мүше',
  noMembers: 'Мүше жоқ',
  codeLabel: 'Код',
  deleteGroup: 'Топты жою',
  deleteGroupConfirm: 'топты жою?',
  removeAdmin: 'Adminдіктен алу',
  makeAdmin: 'Топ admini ету',
  removeFinancier: 'Қаржышыдан алу',
  makeFinancier: 'Қаржышы ету',
  financierRemoved: 'қаржышыдан алынды',
  financierAssigned: 'қаржышы болды 💼',
  changeGroup: 'Топты ауыстыру',
  removeMember: 'Топтан шығару',
  removeMemberConfirm: 'топтан шығару?',
  noOtherGroups: 'Басқа топ жоқ',
  selectNewGroup: 'Жаңа топты таңдаңыз',
  addUser: '➕ Пайдаланушы қосу',
  emailHint: 'Email мекенжайы',
  groupNameLabel: 'Топ атауы',
  startDateOptional: 'Кезең (міндетті емес)',
  selectStartDate: 'Басталу күнін таңдаңыз',
  groupCreated: 'Топ құрылды!',
  userAdded: 'топқа қосылды ✅',
  userAutoJoin: 'тіркелді ✅ Жүйеге кіргенде тобына автоматты қосылады.',
  userAlreadyInGroup: 'бұл топта бар',
  userInOtherGroup: 'жүйеде тіркелген (бұрынғы топта бар). Оны жаңа топқа ауыстыру үшін алдымен бұрынғы топтан шығарыңыз.',
  removedFromGroup: 'Топтан шығарылды',
  adminRemoved: 'adminдіктен алынды',
  adminAssigned: 'топ admini болды 👑',
  updateFailed: 'Жаңарту сәтсіз болды. Supabase RLS рұқсатын тексеріңіз.',
  addFailed: 'Жаңарту сәтсіз: RLS рұқсаты жоқ немесе топ табылмады',
  myAdminsTitle: 'Менің Администраторларым',
  noAdmins: 'Администраторлар жоқ',
  addAdminHint: 'Жаңа admin қосу',
  ungroupedUsers: 'Топсыз пайдаланушылар',
  ungroupedUsersDesc: 'Топтан шығарылған. Тек супер-admin қосымша топ тағайындай алады.',
  maxValuesTitle: 'Максималды мəндер',
  maxValuesHint: 'Осы мəндер негізінде пайыз есептеледі',
  periodHasReports: 'Бұл кезеңде есептер бар. Алдымен есептерді жойыңыз.',

  periods: 'Кезеңдер',
  noPeriods: 'Кезең жоқ',
  createPeriod: 'Кезең құру',
  periodStart: 'Басталу күні',
  periodEnd: 'Аяқталу күні',
  periodCreated: 'Кезең құрылды ✅',
  selectDate: 'Күнді таңдаңыз',
  allowlist: 'Рұқсат тізімі',
  allowedEmails: 'Рұқсат берілген email-дер',
  noAllowedEmails: 'Рұқсат берілген email жоқ',
  addEmail: 'Email қосу',
  emailLabel: 'Email',
  removeFromList: 'Тізімнен өшіру',

  financierLabel: 'Қаржышы',
  paymentsTitle: 'Төлемдер',
  allMembers: 'Барлық мүше',
  thisMonth: 'Осы айда',
  total: 'Жиыны',
  paidLabel: '✅ Төленді',
  unpaidLabel: '❌ Төленбеді',
  noPayments: 'Төлемдер жоқ',
  addPayment: 'Төлем қосу',
  editPayment: 'Төлемді өзгерту',
  amountLabel: 'Сома (₸)',
  paymentDate: 'Төлем күні',
  selectPaymentDate: 'Күнді таңдаңыз',
  monthlyPayment: 'Ай сайынғы төлем',
  extraPayment: 'Экстра төлем',
  paidStatus: 'Төленді ✅',
  unpaidStatus: 'Төленбеді',
  extraLabel: '⚡ Экстра',
  monthlyLabel: '📅 Ай сайын',
  allPaymentsLabel: 'Барлық төлем',
  timesUnit: 'рет',
  deletePaymentConfirm: 'Төлемді жою?',
  switchGroupTitle: 'Топты ауыстыру',
  fixedMonthlyAmount: 'Ай сайынғы белгіленген сома',
  fixedAmountHint: '0',
  fixedAmountLabel: 'Белгіленген сома (₸)',
  partiallyPaidLabel: '⚠️ Толық емес',
  partiallyPaidStatus: 'Толық емес',
  editFixedAmount: 'Белгіленген соманы өзгерту',

  weekLabel: 'Апта',
  monthLabel: 'Ай',
  noReport: 'Есеп жоқ',
  myReport: 'Менің есебім',
  allReports: 'Барлық есептер',
  viewDetail: 'Толығырақ',
  reportSaved: 'Есеп сақталды ✅',
  reportSaving: 'Сақталуда...',

  waitingForGroup: 'Топқа қосылуды күтіңіз',
  waitingDesc: 'Администратор сізді топқа қосады',
  inviteCodeTitle: 'Кіру коды',
  inviteCodeSubtitle: 'Администратордан алған кодыңызды енгізіңіз',
  inviteCodeCheck: 'Тексеру',
  inviteCodeNotFound: 'Код табылмады немесе мерзімі өтті. Администраторға хабарласыңыз.',
  inviteCodeExpired: 'Кодтың мерзімі өтті. Жаңа код сұраңыз.',
  inviteCodeUsed: 'Бұл код бұрын қолданылған. Жаңа код сұраңыз.',
  generateAdminCode: 'Admin коды жасау (7 күн)',
  generateUserCode: 'Қатысушы коды жасау (24 сағат)',
  activeCode: 'Белсенді код',
  noActiveCode: 'Белсенді код жоқ',
  codeExpiresIn: 'Дейін жарамды',
  greeting: 'Сәлем,',
  switchGroupShort: 'ауыстыру',
  noPeriodSelected: 'Кезең таңдалмаған',
  autoCalculated: 'Бұл есеп автоматты есептеледі',
  milestoneStart: 'Бастама жасаңыз!',
  milestoneKeepGoing: 'Жалғастырыңыз!',
  milestoneHalfWay: 'Жарты жол!',
  milestoneGoodProgress: 'Жақсы жүріп жатыр!',
  milestoneExcellent: 'Тамаша нәтиже!',
  groupProgress: 'Топ прогресс',
  perWeek: '/апта',
  paymentUnit: 'төлем',
  youLabel: 'Сіз',
  membersTitle: 'Мүшелер',
  memberRoleLabel: 'Мүше',
  currentWeekLabel: 'Ағымдағы апта',
  weeksAgoSuffix: ' апта бұрын',
  pinCode: 'PIN код',
  pinEnabled: 'Қосулы',
  pinDisabled: 'Өшірулі',
  pinSetup: 'PIN орнату',
  pinChange: 'PIN өзгерту',
  pinDisable: 'PIN өшіру',
  pinEnter: 'PIN кодты енгізіңіз',
  pinNewCode: 'Жаңа PIN код',
  pinConfirm: 'PIN кодты растаңыз',
  pinWrong: 'Қате PIN код',
  pinMismatch: 'PIN коды сәйкес келмеді',
);

// ── Russian strings ────────────────────────────────────────────────────────

const _ru = AppStrings(
  languageCode: 'ru',
  appTitle: 'Ибадат Трекер',
  back: 'Назад',
  cancel: 'Отмена',
  yes: 'Да',
  no: 'Нет',
  save: 'Сохранить',
  add: 'Добавить',
  delete: 'Удалить',
  remove: 'Удалить',
  error: 'Ошибка',
  loading: 'Загрузка...',
  close: 'Закрыть',
  codeCopied: 'Код скопирован',
  retry: 'Повторить',

  appSubtitle: 'Отслеживайте еженедельные ибадаты',
  signInGoogle: 'Войти через Google',
  signingIn: 'Входим...',
  noPassword: 'Пароль не нужен',
  notRegistered: 'Вы не зарегистрированы в системе. Обратитесь к администратору.',
  appLocked: 'Приложение заблокировано',
  unlock: 'Разблокировать',
  switchAccount: 'Войти с другим аккаунтом',
  accessDenied: 'Доступ закрыт',
  notAllowedDesc: 'Вас ещё не зарегистрировал администратор. Обратитесь к нему.',
  profileNotLoaded: 'Профиль не загружен',

  selectGroup: 'Выберите группу',
  groupSubtitle: 'Ведите ибадаты вместе',
  availableGroups: 'Доступные группы',
  noGroupsHint: 'Групп нет. Создайте новую группу',
  currentLabel: 'Текущая',
  createNewGroup: '✨ Создать новую группу',
  groupNameHint: 'Название группы...',
  create: 'Создать',
  creating: 'Создаётся...',

  tabList: 'Список',
  tabReport: 'Отчёт',
  tabAdmin: 'Админ',
  tabCodes: 'Коды',
  tabProfile: 'Профиль',
  tabPayments: 'Платежи',
  allGroups: 'Все группы',
  noGroupSelected: 'Группа не выбрана',
  selectGroupBtn: 'Выбрать группу',
  logout: 'Выйти',

  groupLabel: 'Группа',
  language: 'Язык',
  colorTheme: 'Цвет темы',
  kazakh: 'Қазақша',
  russian: 'Русский',

  adminTitle: 'Управление',
  superAdminLabel: 'Супер Админ',
  groupAdminLabel: 'Гр. Админ',
  memberCount: 'участников',
  noMembers: 'Нет участников',
  codeLabel: 'Код',
  deleteGroup: 'Удалить группу',
  deleteGroupConfirm: 'удалить группу?',
  removeAdmin: 'Снять администратора',
  makeAdmin: 'Назначить администратором',
  removeFinancier: 'Снять финансиста',
  makeFinancier: 'Назначить финансистом',
  financierRemoved: 'снят с роли финансиста',
  financierAssigned: 'назначен финансистом 💼',
  changeGroup: 'Сменить группу',
  removeMember: 'Удалить из группы',
  removeMemberConfirm: 'удалить из группы?',
  noOtherGroups: 'Других групп нет',
  selectNewGroup: 'Выберите новую группу',
  addUser: '➕ Добавить пользователя',
  emailHint: 'Email адрес',
  groupNameLabel: 'Название группы',
  startDateOptional: 'Период (необязательно)',
  selectStartDate: 'Выберите дату начала',
  groupCreated: 'Группа создана!',
  userAdded: 'добавлен в группу ✅',
  userAutoJoin: 'зарегистрирован ✅ При входе автоматически добавится в группу.',
  userAlreadyInGroup: 'уже в этой группе',
  userInOtherGroup: 'зарегистрирован (в другой группе). Сначала удалите из старой группы.',
  removedFromGroup: 'Удалён из группы',
  adminRemoved: 'снят с роли администратора',
  adminAssigned: 'назначен администратором 👑',
  updateFailed: 'Обновление не удалось. Проверьте RLS разрешения Supabase.',
  addFailed: 'Обновление не удалось: нет RLS разрешения или группа не найдена',
  myAdminsTitle: 'Мои администраторы',
  noAdmins: 'Нет администраторов',
  addAdminHint: 'Добавить нового admin',
  ungroupedUsers: 'Пользователи без группы',
  ungroupedUsersDesc: 'Удалены из группы. Только супер-admin может назначить дополнительную группу.',
  maxValuesTitle: 'Максимальные значения',
  maxValuesHint: 'На основе этих значений рассчитываются проценты',
  periodHasReports: 'В этом периоде есть отчёты. Сначала удалите отчёты.',

  periods: 'Периоды',
  noPeriods: 'Периодов нет',
  createPeriod: 'Создать период',
  periodStart: 'Дата начала',
  periodEnd: 'Дата конца',
  periodCreated: 'Период создан ✅',
  selectDate: 'Выберите дату',
  allowlist: 'Список доступа',
  allowedEmails: 'Разрешённые email-адреса',
  noAllowedEmails: 'Разрешённых email нет',
  addEmail: 'Добавить email',
  emailLabel: 'Email',
  removeFromList: 'Удалить из списка',

  financierLabel: 'Финансист',
  paymentsTitle: 'Платежи',
  allMembers: 'Всего участников',
  thisMonth: 'В этом месяце',
  total: 'Итого',
  paidLabel: '✅ Оплачено',
  unpaidLabel: '❌ Не оплачено',
  noPayments: 'Платежей нет',
  addPayment: 'Добавить платёж',
  editPayment: 'Редактировать платёж',
  amountLabel: 'Сумма (₸)',
  paymentDate: 'Дата платежа',
  selectPaymentDate: 'Выберите дату',
  monthlyPayment: 'Ежемесячный платёж',
  extraPayment: 'Дополнительный платёж',
  paidStatus: 'Оплачено ✅',
  unpaidStatus: 'Не оплачено',
  extraLabel: '⚡ Доп.',
  monthlyLabel: '📅 Ежемес.',
  allPaymentsLabel: 'Всего платежей',
  timesUnit: 'раз',
  deletePaymentConfirm: 'Удалить платёж?',
  switchGroupTitle: 'Сменить группу',
  fixedMonthlyAmount: 'Ежемесячная фиксированная сумма',
  fixedAmountHint: '0',
  fixedAmountLabel: 'Фиксированная сумма (₸)',
  partiallyPaidLabel: '⚠️ Частично',
  partiallyPaidStatus: 'Частично оплачено',
  editFixedAmount: 'Изменить фикс. сумму',

  weekLabel: 'Неделя',
  monthLabel: 'Месяц',
  noReport: 'Отчёт отсутствует',
  myReport: 'Мой отчёт',
  allReports: 'Все отчёты',
  viewDetail: 'Подробнее',
  reportSaved: 'Отчёт сохранён ✅',
  reportSaving: 'Сохраняется...',

  waitingForGroup: 'Ожидайте добавления в группу',
  waitingDesc: 'Администратор добавит вас в группу',
  inviteCodeTitle: 'Код доступа',
  inviteCodeSubtitle: 'Введите код, полученный от администратора',
  inviteCodeCheck: 'Проверить',
  inviteCodeNotFound: 'Код не найден или истёк. Обратитесь к администратору.',
  inviteCodeExpired: 'Срок действия кода истёк. Запросите новый.',
  inviteCodeUsed: 'Этот код уже использован. Запросите новый.',
  generateAdminCode: 'Создать код для Admin (7 дней)',
  generateUserCode: 'Создать код для участника (24 часа)',
  activeCode: 'Активный код',
  noActiveCode: 'Активных кодов нет',
  codeExpiresIn: 'Действует до',
  greeting: 'Привет,',
  switchGroupShort: 'изменить',
  noPeriodSelected: 'Период не выбран',
  autoCalculated: 'Этот отчёт считается автоматически',
  milestoneStart: 'Начните!',
  milestoneKeepGoing: 'Продолжайте!',
  milestoneHalfWay: 'Половина пути!',
  milestoneGoodProgress: 'Хорошо идёт!',
  milestoneExcellent: 'Отличный результат!',
  groupProgress: 'Прогресс группы',
  perWeek: '/нед.',
  paymentUnit: 'платёж',
  youLabel: 'Вы',
  membersTitle: 'Участники',
  memberRoleLabel: 'Участник',
  currentWeekLabel: 'Текущая неделя',
  weeksAgoSuffix: ' нед. назад',
  pinCode: 'PIN-код',
  pinEnabled: 'Включён',
  pinDisabled: 'Выключен',
  pinSetup: 'Установить PIN',
  pinChange: 'Изменить PIN',
  pinDisable: 'Отключить PIN',
  pinEnter: 'Введите PIN-код',
  pinNewCode: 'Новый PIN-код',
  pinConfirm: 'Подтвердите PIN-код',
  pinWrong: 'Неверный PIN-код',
  pinMismatch: 'PIN-коды не совпадают',
);

// ── Category / Unit helpers ────────────────────────────────────────────────

extension AppStringsX on AppStrings {
  String categoryLabel(String key) {
    if (languageCode == 'ru') {
      switch (key) {
        case 'quran_pages': return 'Коран';
        case 'book_pages': return 'Книга';
        case 'fasting_days': return 'Пост';
        case 'jawshan_count': return 'Джевшен';
        case 'istighfar_count': return 'Истигфар';
        case 'tahajjud_count': return 'Тахаджуд';
        case 'zikir_count': return 'Зикир';
        case 'salawat_count': return 'Салауат';
        case 'risale_pages': return 'Рисале';
        case 'audio_minutes': return 'Аудио';
      }
    }
    switch (key) {
      case 'quran_pages': return 'Құран';
      case 'book_pages': return 'Кітап';
      case 'jawshan_count': return 'Жевшен';
      case 'fasting_days': return 'Ораза';
      case 'risale_pages': return 'Рисале';
      case 'audio_minutes': return 'Аудио';
      case 'salawat_count': return 'Салауат';
      case 'istighfar_count': return 'Істіғфар';
      case 'tahajjud_count': return 'Таһажуд';
      case 'zikir_count': return 'Зікір';
      default: return key;
    }
  }

  String unitLabel(String kkUnit) {
    if (languageCode == 'ru') {
      switch (kkUnit) {
        case 'бет': return 'стр.';
        case 'рет': return 'раз';
        case 'күн': return 'дн.';
        case 'мін': return 'мин.';
      }
    }
    return kkUnit;
  }
}

// ── Accessor ───────────────────────────────────────────────────────────────

class S {
  static AppStrings of(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return lang == 'ru' ? _ru : _kk;
  }
}
