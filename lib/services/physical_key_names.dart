import 'package:flutter/services.dart';

import '../models/modifier.dart';

// USB HID usage codes are contiguous for letters, digits and F-keys, so those
// ranges are generated instead of listed.
final Map<int, String> _names = {
  for (var i = 0; i < 26; i++)
    PhysicalKeyboardKey.keyA.usbHidUsage + i: String.fromCharCode(97 + i),
  for (var i = 0; i < 9; i++)
    PhysicalKeyboardKey.digit1.usbHidUsage + i: '${i + 1}',
  PhysicalKeyboardKey.digit0.usbHidUsage: '0',
  for (var i = 0; i < 12; i++)
    PhysicalKeyboardKey.f1.usbHidUsage + i: 'f${i + 1}',
  PhysicalKeyboardKey.escape.usbHidUsage: 'esc',
  PhysicalKeyboardKey.enter.usbHidUsage: 'enter',
  PhysicalKeyboardKey.tab.usbHidUsage: 'tab',
  PhysicalKeyboardKey.space.usbHidUsage: 'space',
  PhysicalKeyboardKey.backspace.usbHidUsage: 'backspace',
  PhysicalKeyboardKey.capsLock.usbHidUsage: 'capslock',
  PhysicalKeyboardKey.minus.usbHidUsage: 'minus',
  PhysicalKeyboardKey.equal.usbHidUsage: 'equal',
  PhysicalKeyboardKey.bracketLeft.usbHidUsage: 'leftbrace',
  PhysicalKeyboardKey.bracketRight.usbHidUsage: 'rightbrace',
  PhysicalKeyboardKey.backslash.usbHidUsage: 'backslash',
  PhysicalKeyboardKey.semicolon.usbHidUsage: 'semicolon',
  PhysicalKeyboardKey.quote.usbHidUsage: 'apostrophe',
  PhysicalKeyboardKey.backquote.usbHidUsage: 'grave',
  PhysicalKeyboardKey.comma.usbHidUsage: 'comma',
  PhysicalKeyboardKey.period.usbHidUsage: 'dot',
  PhysicalKeyboardKey.slash.usbHidUsage: 'slash',
  PhysicalKeyboardKey.intlBackslash.usbHidUsage: '102nd',
  PhysicalKeyboardKey.arrowUp.usbHidUsage: 'up',
  PhysicalKeyboardKey.arrowDown.usbHidUsage: 'down',
  PhysicalKeyboardKey.arrowLeft.usbHidUsage: 'left',
  PhysicalKeyboardKey.arrowRight.usbHidUsage: 'right',
  PhysicalKeyboardKey.home.usbHidUsage: 'home',
  PhysicalKeyboardKey.end.usbHidUsage: 'end',
  PhysicalKeyboardKey.pageUp.usbHidUsage: 'pageup',
  PhysicalKeyboardKey.pageDown.usbHidUsage: 'pagedown',
  PhysicalKeyboardKey.insert.usbHidUsage: 'insert',
  PhysicalKeyboardKey.delete.usbHidUsage: 'delete',
  PhysicalKeyboardKey.printScreen.usbHidUsage: 'sysrq',
  PhysicalKeyboardKey.scrollLock.usbHidUsage: 'scrolllock',
  PhysicalKeyboardKey.numLock.usbHidUsage: 'numlock',
  PhysicalKeyboardKey.numpadEnter.usbHidUsage: 'kpenter',
  PhysicalKeyboardKey.contextMenu.usbHidUsage: 'compose',
  PhysicalKeyboardKey.controlLeft.usbHidUsage: 'leftcontrol',
  PhysicalKeyboardKey.controlRight.usbHidUsage: 'rightcontrol',
  PhysicalKeyboardKey.shiftLeft.usbHidUsage: 'leftshift',
  PhysicalKeyboardKey.shiftRight.usbHidUsage: 'rightshift',
  PhysicalKeyboardKey.altLeft.usbHidUsage: 'leftalt',
  PhysicalKeyboardKey.altRight.usbHidUsage: 'rightalt',
  PhysicalKeyboardKey.metaLeft.usbHidUsage: 'leftmeta',
  PhysicalKeyboardKey.metaRight.usbHidUsage: 'rightmeta',
};

final Map<int, Modifier> _modifiers = {
  PhysicalKeyboardKey.controlLeft.usbHidUsage: Modifier.control,
  PhysicalKeyboardKey.controlRight.usbHidUsage: Modifier.control,
  PhysicalKeyboardKey.shiftLeft.usbHidUsage: Modifier.shift,
  PhysicalKeyboardKey.shiftRight.usbHidUsage: Modifier.shift,
  PhysicalKeyboardKey.altLeft.usbHidUsage: Modifier.alt,
  PhysicalKeyboardKey.altRight.usbHidUsage: Modifier.alt,
  PhysicalKeyboardKey.metaLeft.usbHidUsage: Modifier.meta,
  PhysicalKeyboardKey.metaRight.usbHidUsage: Modifier.meta,
};

String? keydNameForPhysicalKey(PhysicalKeyboardKey key) =>
    _names[key.usbHidUsage];

Modifier? modifierForPhysicalKey(PhysicalKeyboardKey key) =>
    _modifiers[key.usbHidUsage];
