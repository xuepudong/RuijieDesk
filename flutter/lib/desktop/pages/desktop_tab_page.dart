import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
// import 'package:flutter/services.dart';

import '../../common/shared_state.dart';

class DesktopTabPage extends StatefulWidget {
  const DesktopTabPage({Key? key}) : super(key: key);

  @override
  State<DesktopTabPage> createState() => _DesktopTabPageState();

  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    try {
      DesktopTabController tabController = Get.find<DesktopTabController>();
      tabController.add(TabInfo(
          key: kTabLabelSettingPage,
          label: kTabLabelSettingPage,
          selectedIcon: Icons.build_sharp,
          unselectedIcon: Icons.build_outlined,
          page: DesktopSettingPage(
            key: const ValueKey(kTabLabelSettingPage),
            initialTabkey: initialPage,
          )));
    } catch (e) {
      debugPrintStack(label: '$e');
    }
  }
}

class _DesktopTabPageState extends State<DesktopTabPage> {
  final tabController = DesktopTabController(tabType: DesktopTabType.main);

  _DesktopTabPageState() {
    RemoteCountState.init();
    Get.put<DesktopTabController>(tabController);
    tabController.add(TabInfo(
        key: kTabLabelHomePage,
        label: kTabLabelHomePage,
        selectedIcon: Icons.home_sharp,
        unselectedIcon: Icons.home_outlined,
        closable: false,
        page: DesktopHomePage(
          key: const ValueKey(kTabLabelHomePage),
        )));
    if (bind.isIncomingOnly()) {
      tabController.onSelected = (key) {
        if (key == kTabLabelHomePage) {
          windowManager.setSize(getIncomingOnlyHomeSize());
          setResizable(false);
        } else {
          windowManager.setSize(getIncomingOnlySettingsSize());
          setResizable(true);
        }
      };
    }
  }

  @override
  void initState() {
    super.initState();
    // HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Check if unlock-pin is configured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUnlockPin();
    });
  }

  void _checkUnlockPin() async {
    final configuredPin = bind.mainGetBuildinOption(key: 'unlock-pin');
    if (configuredPin.isEmpty || configuredPin == 'N') {
      return; // No PIN configured, allow access
    }

    // Show PIN dialog and block until correct PIN is entered
    await _showPinDialog(configuredPin);
  }

  Future<void> _showPinDialog(String correctPin) async {
    final TextEditingController pinController = TextEditingController();
    String errorMsg = '';
    bool pinVerified = false;

    while (!pinVerified) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              return WillPopScope(
                onWillPop: () async => false, // Prevent dialog dismissal
                child: AlertDialog(
                  title: Text(translate('Enter PIN to unlock')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: pinController,
                        obscureText: true,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: translate('PIN Code'),
                          errorText: errorMsg.isEmpty ? null : errorMsg,
                        ),
                        onSubmitted: (value) {
                          Navigator.of(dialogContext).pop(true);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        translate('This application is locked. Enter the correct PIN to continue.'),
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        windowManager.close();
                      },
                      child: Text(translate('Exit')),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(true);
                      },
                      child: Text(translate('OK')),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );

      if (result == true) {
        final enteredPin = pinController.text.trim();
        if (enteredPin == correctPin) {
          pinVerified = true;
        } else {
          errorMsg = translate('Incorrect PIN. Please try again.');
          pinController.clear();
        }
      }
    }
  }

  /*
  bool _handleKeyEvent(KeyEvent event) {
    if (!mouseIn && event is KeyDownEvent) {
      print('key down: ${event.logicalKey}');
      shouldBeBlocked(_block, canBeBlocked);
    }
    return false; // allow it to propagate
  }
  */

  @override
  void dispose() {
    // HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    Get.delete<DesktopTabController>();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabWidget = Container(
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: DesktopTab(
              controller: tabController,
              tail: Offstage(
                offstage: bind.isIncomingOnly() ||
                          bind.isDisableSettings() ||
                          bind.mainGetBuildinOption(key: 'hide-menu-bar') == 'Y',
                child: ActionIcon(
                  message: 'Settings',
                  icon: IconFont.menu,
                  onTap: DesktopTabPage.onAddSetting,
                  isClose: false,
                ),
              ),
            )));
    return isMacOS || kUseCompatibleUiMode
        ? tabWidget
        : Obx(
            () => DragToResizeArea(
              resizeEdgeSize: stateGlobal.resizeEdgeSize.value,
              enableResizeEdges: windowManagerEnableResizeEdges,
              child: tabWidget,
            ),
          );
  }
}
