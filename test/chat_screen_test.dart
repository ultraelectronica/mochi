import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/config/app_config.dart';
import 'package:mochi/models/member.dart';
import 'package:mochi/models/mood.dart';
import 'package:mochi/models/pet.dart';
import 'package:mochi/providers/member_provider.dart';
import 'package:mochi/providers/pet_provider.dart';
import 'package:mochi/screens/chat_screen.dart';
import 'package:mochi/services/stt_service.dart';

class _PetProvider extends PetProvider {
  List<ChatEntry> entries = <ChatEntry>[];
  bool pending = false;
  String? error;

  @override
  Pet get pet => const Pet(
    id: 1,
    name: 'Mochi',
    stageNumber: 3,
    xp: 800,
    mood: MochiMood.normal,
    moodScore: 60,
  );
  @override
  List<ChatEntry> get chatEntries => entries;
  @override
  bool get replyPending => pending;
  @override
  String? get errorMessage => error;

  void update() => notifyListeners();
}

class _MemberProvider extends MemberProvider {
  @override
  Member get currentMember => Member.fromJson(<String, dynamic>{
    'id': 1,
    'name': 'Arne',
    'avatar_color': '#D8F0FF',
  });
}

class _Speech extends SttService {
  bool listening = false;
  bool available = true;
  void Function(String)? result;
  @override
  bool get isListening => listening;
  @override
  Future<bool> initialize() async => available;
  @override
  Future<void> startListening({
    String localeId = 'en_US',
    void Function(String)? onResult,
    void Function(String)? onError,
  }) async {
    result = onResult;
    listening = true;
    onListeningChanged?.call(true);
  }

  @override
  Future<String> stopListening() async {
    listening = false;
    onListeningChanged?.call(false);
    return '';
  }

  @override
  Future<void> cancel() async {
    listening = false;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _PetProvider pet, {
  Future<void> Function(String, {String inputType})? send,
  _Speech? speech,
  Size size = const Size(360, 800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildMochiTheme(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedBuilder(
              animation: pet,
              builder: (context, _) => ChatScreen(
                petProvider: pet,
                memberProvider: _MemberProvider(),
                onSendMessage:
                    send ?? (String text, {String inputType = 'text'}) async {},
                onRefreshHistory: () async {},
                onToggleFullscreen: () {},
                sttService: speech ?? _Speech(),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('starter fills an editable draft and never sends automatically', (
    tester,
  ) async {
    int sends = 0;
    await _pump(
      tester,
      _PetProvider(),
      send: (String text, {String inputType = 'text'}) async {
        sends++;
      },
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Something good happened'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Something good happened',
    );
    expect(sends, 0);
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sends, 1);
  });

  testWidgets(
    'failed sends restore drafts and preserve newer typed text on resend',
    (tester) async {
      final _PetProvider pet = _PetProvider();
      final Completer<void> first = Completer<void>();
      final List<String> sends = <String>[];
      await _pump(
        tester,
        pet,
        send: (String text, {String inputType = 'text'}) async {
          sends.add(text);
          if (sends.length == 1) {
            await first.future;
            pet.error = 'Could not save';
          } else {
            pet.error = null;
          }
        },
      );
      await tester.enterText(find.byType(TextField), 'First message');
      await tester.pump();
      await tester.tap(find.text('Send'));
      await tester.pump();
      first.complete();
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'First message',
      );
      await tester.enterText(find.byType(TextField), 'Next message');
      await tester.tap(find.text('Resend'));
      await tester.pump();
      expect(sends, <String>['First message', 'First message']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Next message',
      );
    },
  );

  testWidgets('voice recording appends a draft and requires explicit send', (
    tester,
  ) async {
    final _Speech speech = _Speech();
    final List<String> sends = <String>[];
    await _pump(
      tester,
      _PetProvider(),
      speech: speech,
      send: (String text, {String inputType = 'text'}) async {
        sends.add('$inputType:$text');
      },
    );
    await tester.enterText(find.byType(TextField), 'Today');
    await tester.tap(find.byTooltip('Record a voice draft'));
    await tester.pump();
    speech.result!('was lovely');
    await tester.pump();
    await tester.tap(find.byTooltip('Stop recording'));
    await tester.pump();
    expect(sends, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Today was lovely',
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sends, <String>['voice:Today was lovely']);
  });

  testWidgets('unavailable microphone offers a typing fallback', (
    tester,
  ) async {
    await _pump(tester, _PetProvider(), speech: _Speech()..available = false);
    await tester.tap(find.byTooltip('Record a voice draft'));
    await tester.pump();
    expect(
      find.textContaining('Check microphone and speech permissions'),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
  });

  testWidgets(
    'streaming follows latest but preserves older-message reading position',
    (tester) async {
      final _PetProvider pet = _PetProvider();
      pet.entries = List<ChatEntry>.generate(
        24,
        (i) => ChatEntry.local(
          author: i.isEven ? 'Arne' : 'Mochi',
          text: 'A little moment number $i.\nMore about my day.',
          isPet: i.isOdd,
        ),
      );
      await _pump(tester, pet);
      await tester.pump(const Duration(milliseconds: 300));
      final ScrollController scroll = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      await tester.drag(find.byType(ListView), const Offset(0, 500));
      await tester.pump(const Duration(milliseconds: 500));
      final double before = scroll.offset;
      pet.entries = <ChatEntry>[
        ...pet.entries,
        ChatEntry.local(author: 'Mochi', text: 'A new reply', isPet: true),
      ];
      pet.update();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.offset, closeTo(before, 1));
      expect(find.text('Jump to latest'), findsOneWidget);
      await tester.tap(find.text('Jump to latest'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(scroll.position.extentAfter, lessThan(100));
    },
  );

  testWidgets('natural voice stop returns to an editable draft', (
    tester,
  ) async {
    final _Speech speech = _Speech();
    await _pump(tester, _PetProvider(), speech: speech);
    await tester.tap(find.byTooltip('Record a voice draft'));
    await tester.pump();
    speech.result!('A tiny moment');
    await speech.stopListening();
    await tester.pump();
    expect(find.byTooltip('Record a voice draft'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'A tiny moment',
    );
  });

  testWidgets('pending replies allow drafting but disable sending', (
    tester,
  ) async {
    final _PetProvider pet = _PetProvider()..pending = true;
    await _pump(tester, pet);
    await tester.enterText(find.byType(TextField), 'For later');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
          .onPressed,
      isNull,
    );
    pet.pending = false;
    pet.update();
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('compact chat supports large text without overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      _PetProvider(),
      size: const Size(320, 640),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byType(TextField),
      'A message\nwith multiple lines',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
