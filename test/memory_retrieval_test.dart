import 'package:flutter_test/flutter_test.dart';
import 'package:mochi/db/mochi_db.dart';
import 'package:mochi/db/mochi_repository.dart';
import 'package:mochi/models/member.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  late MochiDb db;
  late MochiRepository repo;
  late Member profile;

  setUp(() {
    db = MochiDb.openInMemory();
    repo = MochiRepository(db);
    profile = repo.createProfile('Sam', '#1D9E75');
  });

  tearDown(() {
    db.db.close();
  });

  int seedInteraction(String input, String response) {
    final int sessionId = repo.resolveSession(memberId: profile.id);
    return repo.insertInteraction(
      memberId: profile.id,
      sessionId: sessionId,
      inputText: input,
      responseText: response,
      inputType: 'text',
      xpAwarded: 10,
    );
  }

  group('retrieveRelevantMemories (FTS5)', () {
    setUp(() {
      repo.addMemory(memberId: profile.id, content: 'Sam loves rainy days', weight: 3);
      repo.addMemory(memberId: profile.id, content: 'The rain never stops here', weight: 1);
      repo.addMemory(memberId: profile.id, content: 'Sam is afraid of dogs', weight: 2);
    });

    test('returns keyword-matching memories', () {
      final List<String> hits = repo.retrieveRelevantMemories('rain');

      expect(hits, contains('Sam loves rainy days'));
      expect(hits, contains('The rain never stops here'));
    });

    test('returns no dog memory for a rain query', () {
      final List<String> hits = repo.retrieveRelevantMemories('rain');

      expect(hits, isNot(contains('Sam is afraid of dogs')));
    });

    test('respects the k limit', () {
      final List<String> hits = repo.retrieveRelevantMemories('rain', k: 1);

      expect(hits, hasLength(1));
    });

    test('ignores non-matching queries', () {
      final List<String> hits = repo.retrieveRelevantMemories('quantum physics');

      expect(hits, isEmpty);
    });

    test('returns empty for queries with no useable terms', () {
      expect(repo.retrieveRelevantMemories('ab'), isEmpty);
      expect(repo.retrieveRelevantMemories('   '), isEmpty);
    });

    test('appends at most one matching past interaction', () {
      seedInteraction('I love rain a lot', 'Rainy days are cozy.');

      final List<String> hits = repo.retrieveRelevantMemories('rain');

      expect(hits, contains('Rainy days are cozy.'));
      expect(hits.length, lessThanOrEqualTo(4));
    });

    test('excludes the current message from interaction hits', () {
      seedInteraction('I love rain a lot', 'Rainy days are cozy.');

      final List<String> hits = repo.retrieveRelevantMemories(
        'I love rain a lot',
        k: 3,
      );

      expect(hits, isNot(contains('Rainy days are cozy.')));
    });
  });

  group('retrieveRelevantMemories (token-overlap fallback)', () {
    setUp(() {
      repo.forceTokenOverlapFallback = true;
      repo.addMemory(memberId: profile.id, content: 'Sam loves rainy days', weight: 3);
      repo.addMemory(memberId: profile.id, content: 'The rain never stops here', weight: 1);
      repo.addMemory(memberId: profile.id, content: 'Sam is afraid of dogs', weight: 2);
    });

    test('scores weight*10 + recency, weight wins', () {
      expect(repo.retrieveRelevantMemories('rain').first, 'Sam loves rainy days');
    });

    test('matches on token overlap only', () {
      final List<String> hits = repo.retrieveRelevantMemories('dogs');

      expect(hits, hasLength(1));
      expect(hits.first, 'Sam is afraid of dogs');
    });

    test('appends a matching interaction from recent history', () {
      seedInteraction('I love rain a lot', 'Rainy days are cozy.');

      expect(
        repo.retrieveRelevantMemories('rain'),
        contains('Rainy days are cozy.'),
      );
    });

    test('respects the k limit through the overlap path', () {
      final List<String> hits = repo.retrieveRelevantMemories('rain', k: 1);

      expect(hits, hasLength(1));
      expect(hits.first, 'Sam loves rainy days');
    });
  });

  group('FTS5 sync repair', () {
    test('rebuild fixes a desynced index that broke memory deletes',
        () {
      repo.addMemory(
        memberId: profile.id,
        content: 'Sam loves rainy days',
        weight: 3,
      );

      // Drift: wipe the FTS index while the content row remains (what a
      // crash/restore leaves behind). The after-DELETE trigger then fails
      // with SQLITE_CORRUPT (267) on any memory delete.
      db.db
          .execute("INSERT INTO memories_fts(memories_fts) VALUES('delete-all');");

      final int id = repo.listMemories().single.id;
      expect(
        () => db.db.execute(
          'DELETE FROM memories WHERE id = ?',
          <Object?>[id],
        ),
        throwsA(isA<sqlite3.SqliteException>()),
      );

      MochiDb.repairFtsSync(db.db);

      expect(
        () => db.db.execute(
          'DELETE FROM memories WHERE id = ?',
          <Object?>[id],
        ),
        returnsNormally,
      );
      expect(repo.listMemories(), isEmpty);
      expect(repo.retrieveRelevantMemories('rain'), isEmpty);
    });
  });
}
