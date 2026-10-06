/// 应用级 UI 壳层的统一导出。
///
/// 业务页只 import 本文件即可拿到全部 App* 壳，
/// **不要**在业务页直接 import forui 或裸用 F* 组件。
///
/// 页头：一级页 `AppPageHeader`、二级页 `AppTopBar`、页头图标 `AppHeaderAction`
/// 三者同在 `app_page_header.dart`，共用一套几何令牌（见该文件顶部常量）。
library;

export 'app_button.dart';
export 'app_card.dart';
export 'app_confirm_dialog.dart';
export 'app_fab.dart';
export 'app_input_dialog.dart';
export 'app_page_header.dart';
export 'app_picker_sheet.dart';
export 'app_switch.dart';
export 'app_tabs.dart';
export 'app_text_field.dart';
export 'app_tile.dart';
export 'app_toast.dart';
export 'choice_chips.dart';
export 'empty_state.dart';
export 'form_widgets.dart';
export 'segmented_control.dart';
export 'status_pill.dart';
export 'surface_card.dart';
