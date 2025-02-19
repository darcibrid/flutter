// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget _boilerplate(VoidCallback? onButtonPressed, {
    DraggableScrollableController? controller,
    int itemCount = 100,
    double initialChildSize = .5,
    double maxChildSize = 1.0,
    double minChildSize = .25,
    bool snap = false,
    List<double>? snapSizes,
    double? itemExtent,
    Key? containerKey,
    Key? stackKey,
    NotificationListenerCallback<ScrollNotification>? onScrollNotification,
    bool ignoreController = false,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Stack(
          key: stackKey,
          children: <Widget>[
            TextButton(
              onPressed: onButtonPressed,
              child: const Text('TapHere'),
            ),
            DraggableScrollableActuator(
              child: DraggableScrollableSheet(
                controller: controller,
                maxChildSize: maxChildSize,
                minChildSize: minChildSize,
                initialChildSize: initialChildSize,
                snap: snap,
                snapSizes: snapSizes,
                builder: (BuildContext context, ScrollController scrollController) {
                  return NotificationListener<ScrollNotification>(
                    onNotification: onScrollNotification,
                    child: Container(
                      key: containerKey,
                      color: const Color(0xFFABCDEF),
                      child: ListView.builder(
                        controller: ignoreController ? null : scrollController,
                        itemExtent: itemExtent,
                        itemCount: itemCount,
                        itemBuilder: (BuildContext context, int index) => Text('Item $index'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('Scrolls correct amount when maxChildSize < 1.0', (WidgetTester tester) async {
    const Key key = ValueKey<String>('container');
    await tester.pumpWidget(_boilerplate(
      null,
      maxChildSize: .6,
      initialChildSize: .25,
      itemExtent: 25.0,
      containerKey: key,
    ));

    expect(tester.getRect(find.byKey(key)), const Rect.fromLTRB(0.0, 450.0, 800.0, 600.0));
    await tester.drag(find.text('Item 5'), const Offset(0, -125));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(key)), const Rect.fromLTRB(0.0, 325.0, 800.0, 600.0));
  });

  testWidgets('Scrolls correct amount when maxChildSize == 1.0', (WidgetTester tester) async {
    const Key key = ValueKey<String>('container');
    await tester.pumpWidget(_boilerplate(
      null,
      initialChildSize: .25,
      itemExtent: 25.0,
      containerKey: key,
    ));

    expect(tester.getRect(find.byKey(key)), const Rect.fromLTRB(0.0, 450.0, 800.0, 600.0));
    await tester.drag(find.text('Item 5'), const Offset(0, -125));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(key)), const Rect.fromLTRB(0.0, 325.0, 800.0, 600.0));
  });

  testWidgets('Invalid snap targets throw assertion errors.', (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(
      null,
      maxChildSize: .8,
      snapSizes: <double>[.9],
    ));
    expect(tester.takeException(), isAssertionError);

    await tester.pumpWidget(_boilerplate(
      null,
      snapSizes: <double>[.1],
    ));
    expect(tester.takeException(), isAssertionError);

    await tester.pumpWidget(_boilerplate(
      null,
      snapSizes: <double>[.6, .6, .9],
    ));
    expect(tester.takeException(), isAssertionError);
  });

  group('Scroll Physics', () {
    testWidgets('Can be dragged up without covering its container', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_boilerplate(() => taps++));

      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 31'), findsNothing);

      await tester.drag(find.text('Item 1'), const Offset(0, -200));
      await tester.pumpAndSettle();
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 2);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 31'), findsOneWidget);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Can be dragged down when not full height', (WidgetTester tester) async {
      await tester.pumpWidget(_boilerplate(null));
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 36'), findsNothing);

      await tester.drag(find.text('Item 1'), const Offset(0, 325));
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsNothing);
      expect(find.text('Item 36'), findsNothing);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Can be dragged down when list is shorter than full height', (WidgetTester tester) async {
      await tester.pumpWidget(_boilerplate(null, itemCount: 30, initialChildSize: .25));

      expect(find.text('Item 1').hitTestable(), findsOneWidget);
      expect(find.text('Item 29').hitTestable(), findsNothing);

      await tester.drag(find.text('Item 1'), const Offset(0, -325));
      await tester.pumpAndSettle();
      expect(find.text('Item 1').hitTestable(), findsOneWidget);
      expect(find.text('Item 29').hitTestable(), findsOneWidget);

      await tester.drag(find.text('Item 1'), const Offset(0, 325));
      await tester.pumpAndSettle();
      expect(find.text('Item 1').hitTestable(), findsOneWidget);
      expect(find.text('Item 29').hitTestable(), findsNothing);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Can be dragged up and cover its container and scroll in single motion, and then dragged back down', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_boilerplate(() => taps++));

      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 36'), findsNothing);

      await tester.drag(find.text('Item 1'), const Offset(0, -325));
      await tester.pumpAndSettle();
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'), warnIfMissed: false);
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 36'), findsOneWidget);

      await tester.dragFrom(const Offset(20, 20), const Offset(0, 325));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TapHere'));
      expect(taps, 2);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 18'), findsOneWidget);
      expect(find.text('Item 36'), findsNothing);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Can be flung up gently', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_boilerplate(() => taps++));

      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 36'), findsNothing);
      expect(find.text('Item 70'), findsNothing);

      await tester.fling(find.text('Item 1'), const Offset(0, -200), 350);
      await tester.pumpAndSettle();
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 2);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 36'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Can be flung up', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_boilerplate(() => taps++));

      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);

      await tester.fling(find.text('Item 1'), const Offset(0, -200), 2000);
      await tester.pumpAndSettle();
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'), warnIfMissed: false);
      expect(taps, 1);
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 21'), findsNothing);
      expect(find.text('Item 70'), findsOneWidget);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Can be flung down when not full height', (WidgetTester tester) async {
      await tester.pumpWidget(_boilerplate(null));
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 36'), findsNothing);

      await tester.fling(find.text('Item 1'), const Offset(0, 325), 2000);
      await tester.pumpAndSettle();
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsNothing);
      expect(find.text('Item 36'), findsNothing);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Can be flung up and then back down', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_boilerplate(() => taps++));

      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);

      await tester.fling(find.text('Item 1'), const Offset(0, -200), 2000);
      await tester.pumpAndSettle();
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'), warnIfMissed: false);
      expect(taps, 1);
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 21'), findsNothing);
      expect(find.text('Item 70'), findsOneWidget);

      await tester.fling(find.text('Item 70'), const Offset(0, 200), 2000);
      await tester.pumpAndSettle();
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'), warnIfMissed: false);
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);

      await tester.fling(find.text('Item 1'), const Offset(0, 200), 2000);
      await tester.pumpAndSettle();
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 2);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 21'), findsNothing);
      expect(find.text('Item 70'), findsNothing);
    }, variant: TargetPlatformVariant.all());

    testWidgets('Ballistic animation on fling can be interrupted', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_boilerplate(() => taps++));

      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'));
      expect(taps, 1);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 31'), findsNothing);
      expect(find.text('Item 70'), findsNothing);

      await tester.fling(find.text('Item 1'), const Offset(0, -200), 2000);
      // Don't pump and settle because we want to interrupt the ballistic scrolling animation.
      expect(find.text('TapHere'), findsOneWidget);
      await tester.tap(find.text('TapHere'), warnIfMissed: false);
      expect(taps, 2);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 31'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);

      // Use `dragFrom` here because calling `drag` on a list item without
      // first calling `pumpAndSettle` fails with a hit test error.
      await tester.dragFrom(const Offset(0, 200), const Offset(0, 200));
      await tester.pumpAndSettle();

      // Verify that the ballistic animation has canceled and the sheet has
      // returned to it's original position.
      await tester.tap(find.text('TapHere'));
      expect(taps, 3);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 31'), findsNothing);
      expect(find.text('Item 70'), findsNothing);
    }, variant: TargetPlatformVariant.all());

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Does not snap away from initial child on build', (WidgetTester tester) async {
    const Key containerKey = ValueKey<String>('container');
    const Key stackKey = ValueKey<String>('stack');
    await tester.pumpWidget(_boilerplate(null,
      snap: true,
      initialChildSize: .7,
      containerKey: containerKey,
      stackKey: stackKey,
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    // The sheet should not have snapped.
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.7, precisionErrorTolerance,
    ));
  }, variant: TargetPlatformVariant.all());

  for (final bool useActuator in <bool>[false, true]) {
    testWidgets('Does not snap away from initial child on ${useActuator ? 'actuator' : 'controller'}.reset()', (WidgetTester tester) async {
      const Key containerKey = ValueKey<String>('container');
      const Key stackKey = ValueKey<String>('stack');
      final DraggableScrollableController controller = DraggableScrollableController();
      await tester.pumpWidget(_boilerplate(
        null,
        controller: controller,
        snap: true,
        containerKey: containerKey,
        stackKey: stackKey,
      ));
      await tester.pumpAndSettle();
      final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

      await tester.drag(find.text('Item 1'), Offset(0, -.4 * screenHeight));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(1.0, precisionErrorTolerance),
      );

      if (useActuator) {
        DraggableScrollableActuator.reset(tester.element(find.byKey(containerKey)));
      } else {
        controller.reset();
      }
      await tester.pumpAndSettle();

      // The sheet should have reset without snapping away from initial child.
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(.5, precisionErrorTolerance),
      );
    });
  }

  testWidgets('Zero velocity drag snaps to nearest snap target', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    await tester.pumpWidget(_boilerplate(null,
      snap: true,
      stackKey: stackKey,
      containerKey: containerKey,
      snapSizes: <double>[.25, .5, .75, 1.0],
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    // We are dragging up, but we'll snap down because we're closer to .75 than 1.
    await tester.drag(find.text('Item 1'), Offset(0, -.35 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.75, precisionErrorTolerance),
    );

    // Drag up and snap up.
    await tester.drag(find.text('Item 1'), Offset(0, -.2 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(1.0, precisionErrorTolerance),
    );

    // Drag down and snap up.
    await tester.drag(find.text('Item 1'), Offset(0, .1 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(1.0, precisionErrorTolerance),
    );

    // Drag down and snap down.
    await tester.drag(find.text('Item 1'), Offset(0, .45 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.5, precisionErrorTolerance),
    );

    // Fling up with negligible velocity and snap down.
    await tester.fling(find.text('Item 1'), Offset(0, .1 * screenHeight), 1);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.5, precisionErrorTolerance),
    );
  }, variant: TargetPlatformVariant.all());

  for (final List<double>? snapSizes in <List<double>?>[null, <double>[]]) {
    testWidgets('Setting snapSizes to $snapSizes resolves to min and max', (WidgetTester tester) async {
      const Key stackKey = ValueKey<String>('stack');
      const Key containerKey = ValueKey<String>('container');
      await tester.pumpWidget(_boilerplate(null,
        snap: true,
        stackKey: stackKey,
        containerKey: containerKey,
        snapSizes: snapSizes,
      ));
      await tester.pumpAndSettle();
      final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

      await tester.drag(find.text('Item 1'), Offset(0, -.4 * screenHeight));
      await tester.pumpAndSettle();
      expect(
          tester.getSize(find.byKey(containerKey)).height / screenHeight,
          closeTo(1.0, precisionErrorTolerance,
          ));

      await tester.drag(find.text('Item 1'), Offset(0, .7 * screenHeight));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(.25, precisionErrorTolerance),
      );
    }, variant: TargetPlatformVariant.all());
  }

  testWidgets('Min and max are implicitly added to snapSizes', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    await tester.pumpWidget(_boilerplate(null,
      snap: true,
      stackKey: stackKey,
      containerKey: containerKey,
      snapSizes: <double>[.5],
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    await tester.drag(find.text('Item 1'), Offset(0, -.4 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(1.0, precisionErrorTolerance),
    );

    await tester.drag(find.text('Item 1'), Offset(0, .7 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.25, precisionErrorTolerance),
    );
  }, variant: TargetPlatformVariant.all());

  testWidgets('Changes to widget parameters are propagated', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    await tester.pumpWidget(_boilerplate(
      null,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.5, precisionErrorTolerance),
    );

    // Pump the same widget but with a new initial child size.
    await tester.pumpWidget(_boilerplate(
      null,
      stackKey: stackKey,
      containerKey: containerKey,
      initialChildSize: .6,
    ));
    await tester.pumpAndSettle();

    // We jump to the new initial size because the sheet hasn't changed yet.
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.6, precisionErrorTolerance),
    );

    // Pump the same widget but with a new max child size.
    await tester.pumpWidget(_boilerplate(
      null,
      stackKey: stackKey,
      containerKey: containerKey,
      initialChildSize: .6,
      maxChildSize: .9
    ));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.6, precisionErrorTolerance),
    );

    await tester.drag(find.text('Item 1'), Offset(0, -.6 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.9, precisionErrorTolerance),
    );

    // Pump the same widget but with a new max child size and initial size.
    await tester.pumpWidget(_boilerplate(
      null,
      stackKey: stackKey,
      containerKey: containerKey,
      maxChildSize: .8,
      initialChildSize: .7,
    ));
    await tester.pumpAndSettle();

    // The max child size has been reduced, we should be rebuilt at the new
    // max of .8. We changed the initial size again, but the sheet has already
    // been changed so the new initial is ignored.
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.8, precisionErrorTolerance),
    );

    await tester.drag(find.text('Item 1'), Offset(0, .2 * screenHeight));

    // Pump the same widget but with snapping enabled.
    await tester.pumpWidget(_boilerplate(
      null,
      snap: true,
      stackKey: stackKey,
      containerKey: containerKey,
      maxChildSize: .8,
      snapSizes: <double>[.5],
    ));
    await tester.pumpAndSettle();

    // Sheet snaps immediately on a change to snap.
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.5, precisionErrorTolerance),
    );

    final List<double> snapSizes = <double>[.6];

    // Change the snap sizes.
    await tester.pumpWidget(_boilerplate(
      null,
      snap: true,
      stackKey: stackKey,
      containerKey: containerKey,
      maxChildSize: .8,
      snapSizes: snapSizes,
    ));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.6, precisionErrorTolerance),
    );
  }, variant: TargetPlatformVariant.all());

  testWidgets('Fling snaps in direction of momentum', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    await tester.pumpWidget(_boilerplate(null,
      snap: true,
      stackKey: stackKey,
      containerKey: containerKey,
      snapSizes: <double>[.5, .75],
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    await tester.fling(find.text('Item 1'), Offset(0, -.1 * screenHeight), 1000);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.75, precisionErrorTolerance),
    );

    await tester.fling(find.text('Item 1'), Offset(0, .3 * screenHeight), 1000);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.25, precisionErrorTolerance),
    );

  }, variant: TargetPlatformVariant.all());

  testWidgets("Changing parameters with an un-listened controller doesn't throw", (WidgetTester tester) async {
    await tester.pumpWidget(_boilerplate(
      null,
      snap: true,
      // Will prevent the sheet's child from listening to the controller.
      ignoreController: true,
    ));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_boilerplate(
      null,
      snap: true,
    ));
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.all());

  testWidgets('ScrollNotification correctly dispatched when flung without covering its container', (WidgetTester tester) async {
    final List<Type> notificationTypes = <Type>[];
    await tester.pumpWidget(_boilerplate(
      null,
      onScrollNotification: (ScrollNotification notification) {
        notificationTypes.add(notification.runtimeType);
        return false;
      },
    ));

    await tester.fling(find.text('Item 1'), const Offset(0, -200), 200);
    await tester.pumpAndSettle();

    // TODO(itome): Make sure UserScrollNotification and ScrollUpdateNotification are called correctly.
    final List<Type> types = <Type>[
      ScrollStartNotification,
      ScrollEndNotification,
    ];
    expect(notificationTypes, equals(types));
  });

  testWidgets('ScrollNotification correctly dispatched when flung with contents scroll', (WidgetTester tester) async {
    final List<Type> notificationTypes = <Type>[];
    await tester.pumpWidget(_boilerplate(
      null,
      onScrollNotification: (ScrollNotification notification) {
        notificationTypes.add(notification.runtimeType);
        return false;
      },
    ));

    await tester.flingFrom(const Offset(0, 325), const Offset(0, -325), 200);
    await tester.pumpAndSettle();

    final List<Type> types = <Type>[
      ScrollStartNotification,
      UserScrollNotification,
      ...List<Type>.filled(5, ScrollUpdateNotification),
      ScrollEndNotification,
      UserScrollNotification,
    ];
    expect(notificationTypes, types);
  });

  testWidgets('Do not crash when remove the tree during animation.', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/89214
    await tester.pumpWidget(_boilerplate(
      null,
      onScrollNotification: (ScrollNotification notification) {
        return false;
      },
    ));

    await tester.flingFrom(const Offset(0, 325), const Offset(0, 325), 200);

    // The animation is running.

    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });

  for (final bool shouldAnimate in <bool>[true, false]) {
    testWidgets('Can ${shouldAnimate ? 'animate' : 'jump'} to arbitrary positions', (WidgetTester tester) async {
      const Key stackKey = ValueKey<String>('stack');
      const Key containerKey = ValueKey<String>('container');
      final DraggableScrollableController controller = DraggableScrollableController();
      await tester.pumpWidget(_boilerplate(
        null,
        controller: controller,
        stackKey: stackKey,
        containerKey: containerKey,
      ));
      await tester.pumpAndSettle();
      final double screenHeight = tester.getSize(find.byKey(stackKey)).height;
      // Use a local helper to animate so we can share code across a jumpTo test
      // and an animateTo test.
      void goTo(double size) => shouldAnimate
          ? controller.animateTo(size, duration: const Duration(milliseconds: 200), curve: Curves.linear)
          : controller.jumpTo(size);
      // If we're animating, pump will call four times, two of which are for the
      // animation duration.
      final int expectedPumpCount = shouldAnimate ? 4 : 2;

      goTo(.6);
      expect(await tester.pumpAndSettle(), expectedPumpCount);
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(.6, precisionErrorTolerance),
      );
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 20'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);

      goTo(.4);
      expect(await tester.pumpAndSettle(), expectedPumpCount);
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(.4, precisionErrorTolerance),
      );
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 20'), findsNothing);
      expect(find.text('Item 70'), findsNothing);

      await tester.fling(find.text('Item 1'), Offset(0, -screenHeight), 100);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(1, precisionErrorTolerance),
      );
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 20'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);

      // Programmatic control does not affect the inner scrollable's position.
      goTo(.8);
      expect(await tester.pumpAndSettle(), expectedPumpCount);
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(.8, precisionErrorTolerance),
      );
      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 20'), findsOneWidget);
      expect(find.text('Item 70'), findsNothing);

      // Attempting to move to a size too big or too small instead moves to the
      // min or max child size.
      goTo(.5);
      await tester.pumpAndSettle();
      goTo(0);
      // The animation was cut short by half, there should have been on less pumps
      final int truncatedPumpCount = shouldAnimate ? expectedPumpCount - 1 : expectedPumpCount;
      expect(await tester.pumpAndSettle(), truncatedPumpCount);
      expect(
        tester.getSize(find.byKey(containerKey)).height / screenHeight,
        closeTo(.25, precisionErrorTolerance),
      );
    });
  }

  testWidgets('Can reuse a controller after the old controller is disposed', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final DraggableScrollableController controller = DraggableScrollableController();
    await tester.pumpWidget(_boilerplate(
      null,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    await tester.pumpAndSettle();

    // Pump a new sheet with the same controller. This will dispose of the old sheet first.
    await tester.pumpWidget(_boilerplate(
      null,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    controller.jumpTo(.6);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.6, precisionErrorTolerance),
    );
  });

  testWidgets('animateTo interrupts other animations', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final DraggableScrollableController controller = DraggableScrollableController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _boilerplate(
        null,
        controller: controller,
        stackKey: stackKey,
        containerKey: containerKey,
      ),
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    await tester.flingFrom(Offset(0, .5*screenHeight), Offset(0, -.5*screenHeight), 2000);
    // Wait until `flinFrom` finished dragging, but before the scrollable goes ballistic.
    await tester.pump(const Duration(seconds: 1));

    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(1, precisionErrorTolerance),
    );
    expect(find.text('Item 1'), findsOneWidget);

    controller.animateTo(.9, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.9, precisionErrorTolerance),
    );
    // The ballistic animation should have been canceled so item 1 should still be visible.
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('Other animations interrupt animateTo', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final DraggableScrollableController controller = DraggableScrollableController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _boilerplate(
        null,
        controller: controller,
        stackKey: stackKey,
        containerKey: containerKey,
      ),
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    controller.animateTo(1, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.75, precisionErrorTolerance),
    );

    // Interrupt animation and drag downward.
    await tester.drag(find.text('Item 1'), Offset(0, .1 * screenHeight));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.65, precisionErrorTolerance),
    );
  });

  testWidgets('animateTo can be interrupted by other animateTo or jumpTo', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final DraggableScrollableController controller = DraggableScrollableController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: _boilerplate(
        null,
        controller: controller,
        stackKey: stackKey,
        containerKey: containerKey,
      ),
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    controller.animateTo(1, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.75, precisionErrorTolerance),
    );

    // Interrupt animation with a new `animateTo`.
    controller.animateTo(.25, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.5, precisionErrorTolerance),
    );

    // Interrupt animation with a jump.
    controller.jumpTo(.6);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.6, precisionErrorTolerance),
    );
  });

  testWidgets('Can get size and pixels', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final DraggableScrollableController controller = DraggableScrollableController();
    await tester.pumpWidget(_boilerplate(
      null,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester.getSize(find.byKey(stackKey)).height;

    expect(controller.sizeToPixels(.25), .25*screenHeight);
    expect(controller.pixelsToSize(.25*screenHeight), .25);

    controller.animateTo(.6, duration: const Duration(milliseconds: 200), curve: Curves.linear);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(containerKey)).height / screenHeight,
      closeTo(.6, precisionErrorTolerance),
    );
    expect(controller.size, closeTo(.6, precisionErrorTolerance));
    expect(controller.pixels, closeTo(.6*screenHeight, precisionErrorTolerance));

    await tester.drag(find.text('Item 5'), Offset(0, .2*screenHeight));
    expect(controller.size, closeTo(.4, precisionErrorTolerance));
    expect(controller.pixels, closeTo(.4*screenHeight, precisionErrorTolerance));
  });

  testWidgets('Cannot attach a controller to multiple sheets', (WidgetTester tester) async {
    final DraggableScrollableController controller = DraggableScrollableController();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          _boilerplate(
            null,
            controller: controller,
          ),
          _boilerplate(
            null,
            controller: controller,
          )
        ],
      ),
    ), null, EnginePhase.build);
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('Can listen for changes in sheet size', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final List<double> loggedSizes = <double>[];
    final DraggableScrollableController controller = DraggableScrollableController();
    controller.addListener(() {
      loggedSizes.add(controller.size);
    });
    await tester.pumpWidget(_boilerplate(
      null,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester
        .getSize(find.byKey(stackKey))
        .height;

    // The initial size shouldn't be logged because no change has occurred yet.
    expect(loggedSizes.isEmpty, true);

    await tester.drag(find.text('Item 1'), Offset(0, .1 * screenHeight), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.4].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();

    await tester.timedDrag(find.text('Item 1'), Offset(0, -.1 * screenHeight), const Duration(seconds: 1), frequency: 2);
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.45, .5].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();

    controller.jumpTo(.6);
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.6].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();

    controller.animateTo(1, duration: const Duration(milliseconds: 400), curve: Curves.linear);
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.7, .8, .9, 1].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();

    DraggableScrollableActuator.reset(tester.element(find.byKey(containerKey)));
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.5].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();
  });

  testWidgets('Listener does not fire on parameter change and persists after change', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final List<double> loggedSizes = <double>[];
    final DraggableScrollableController controller = DraggableScrollableController();
    controller.addListener(() {
      loggedSizes.add(controller.size);
    });
    await tester.pumpWidget(_boilerplate(
      null,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester
        .getSize(find.byKey(stackKey))
        .height;

    expect(loggedSizes.isEmpty, true);

    await tester.drag(find.text('Item 1'), Offset(0, .1 * screenHeight), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.4].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();

    // Update a parameter without forcing a change in the current size.
    await tester.pumpWidget(_boilerplate(
      null,
      minChildSize: .1,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    expect(loggedSizes.isEmpty, true);

    await tester.drag(find.text('Item 1'), Offset(0, .1 * screenHeight), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.3].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();
  });

  testWidgets('Listener fires if a parameter change forces a change in size', (WidgetTester tester) async {
    const Key stackKey = ValueKey<String>('stack');
    const Key containerKey = ValueKey<String>('container');
    final List<double> loggedSizes = <double>[];
    final DraggableScrollableController controller = DraggableScrollableController();
    controller.addListener(() {
      loggedSizes.add(controller.size);
    });
    await tester.pumpWidget(_boilerplate(
      null,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    await tester.pumpAndSettle();
    final double screenHeight = tester
        .getSize(find.byKey(stackKey))
        .height;

    expect(loggedSizes.isEmpty, true);

    // Set a new `initialChildSize` which will trigger a size change because we
    // haven't moved away initial size yet.
    await tester.pumpWidget(_boilerplate(
      null,
      initialChildSize: .6,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    expect(loggedSizes, <double>[.6].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();

    // Move away from initial child size.
    await tester.drag(find.text('Item 1'), Offset(0, .3 * screenHeight), touchSlopY: 0);
    await tester.pumpAndSettle();
    expect(loggedSizes, <double>[.3].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();

    // Set a `minChildSize` greater than the current size.
    await tester.pumpWidget(_boilerplate(
      null,
      minChildSize: .4,
      controller: controller,
      stackKey: stackKey,
      containerKey: containerKey,
    ));
    expect(loggedSizes, <double>[.4].map((double v) => closeTo(v, precisionErrorTolerance)));
    loggedSizes.clear();
  });

  testWidgets('Invalid controller interactions throw assertion errors', (WidgetTester tester) async {
    final DraggableScrollableController controller = DraggableScrollableController();
    // Can't use a controller before attaching it.
    expect(() => controller.jumpTo(.1), throwsAssertionError);

    expect(() => controller.pixels, throwsAssertionError);
    expect(() => controller.size, throwsAssertionError);
    expect(() => controller.pixelsToSize(0), throwsAssertionError);
    expect(() => controller.sizeToPixels(0), throwsAssertionError);

    await tester.pumpWidget(_boilerplate(
      null,
      controller: controller,
    ));


    // Can't jump or animate to invalid sizes.
    expect(() => controller.jumpTo(-1), throwsAssertionError);
    expect(() => controller.jumpTo(1.1), throwsAssertionError);
    expect(
      () => controller.animateTo(-1, duration: const Duration(milliseconds: 1), curve: Curves.linear),
      throwsAssertionError,
    );
    expect(
      () => controller.animateTo(1.1, duration: const Duration(milliseconds: 1), curve: Curves.linear),
      throwsAssertionError,
    );

    // Can't use animateTo with a zero duration.
    expect(() => controller.animateTo(.5, duration: Duration.zero, curve: Curves.linear), throwsAssertionError);
  });
}
