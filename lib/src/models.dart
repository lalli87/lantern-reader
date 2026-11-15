/// Plain data classes shared across the app.
library;

int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// Shelf values for [Book.shelf].
const shelfNone = 0, shelfToRead = 1, shelfFinished = 2;

class Book {
  int? id;
  String title, author, series, language, description, format, sourceUrl, fileName, review;
  double? seriesNo;
  int fileSize, addedAt, lastReadAt, curChapter, curPara, shelf, trashedAt, chapterCount, charCount;
  double progress;
  bool favorite;
  String? coverPath;

  Book({
    this.id,
    required this.title,
    this.author = '',
    this.series = '',
    this.seriesNo,
    this.language = '',
    this.description = '',
    this.format = 'WEB',
    this.sourceUrl = '',
    this.fileName = '',
    this.review = '',
    this.fileSize = 0,
    int? addedAt,
    this.lastReadAt = 0,
    this.curChapter = 0,
    this.curPara = 0,
    this.shelf = shelfNone,
    this.trashedAt = 0,
    this.chapterCount = 0,
    this.charCount = 0,
    this.progress = 0,
    this.favorite = false,
    this.coverPath,
  }) : addedAt = addedAt ?? nowMs();

  factory Book.fromMap(Map<String, Object?> m) => Book(
        id: m['id'] as int?,
        title: m['title'] as String? ?? '',
        author: m['author'] as String? ?? '',
        series: m['series'] as String? ?? '',
        seriesNo: (m['series_no'] as num?)?.toDouble(),
        language: m['language'] as String? ?? '',
        description: m['description'] as String? ?? '',
        format: m['format'] as String? ?? 'WEB',
        sourceUrl: m['source_url'] as String? ?? '',
        fileName: m['file_name'] as String? ?? '',
        review: m['review'] as String? ?? '',
        fileSize: m['file_size'] as int? ?? 0,
        addedAt: m['added_at'] as int? ?? 0,
        lastReadAt: m['last_read_at'] as int? ?? 0,
        curChapter: m['cur_chapter'] as int? ?? 0,
        curPara: m['cur_para'] as int? ?? 0,
        shelf: m['shelf'] as int? ?? 0,
        trashedAt: m['trashed_at'] as int? ?? 0,
        chapterCount: m['chapter_count'] as int? ?? 0,
        charCount: m['char_count'] as int? ?? 0,
        progress: (m['progress'] as num?)?.toDouble() ?? 0,
        favorite: (m['favorite'] as int? ?? 0) != 0,
        coverPath: m['cover_path'] as String?,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'author': author,
        'series': series,
        'series_no': seriesNo,
        'language': language,
        'description': description,
        'format': format,
        'source_url': sourceUrl,
        'file_name': fileName,
        'review': review,
        'file_size': fileSize,
        'added_at': addedAt,
        'last_read_at': lastReadAt,
        'cur_chapter': curChapter,
        'cur_para': curPara,
        'shelf': shelf,
        'trashed_at': trashedAt,
        'chapter_count': chapterCount,
        'char_count': charCount,
        'progress': progress,
        'favorite': favorite ? 1 : 0,
        'cover_path': coverPath,
      };
}

/// Chapter without its text, for lists and navigation.
class ChapterMeta {
  final int id, bookId, idx, charCount;
  final String title, url;
  final bool hasTranslation;
  ChapterMeta(this.id, this.bookId, this.idx, this.title, this.url, this.charCount, this.hasTranslation);

  factory ChapterMeta.fromMap(Map<String, Object?> m) => ChapterMeta(
        m['id'] as int,
        m['book_id'] as int,
        m['idx'] as int,
        m['title'] as String? ?? '',
        m['url'] as String? ?? '',
        m['char_count'] as int? ?? 0,
        (m['has_tr'] as int? ?? 0) != 0,
      );
}

class Chapter {
  int? id;
  int bookId, idx, addedAt;
  String title, url, content, translated, translatedLang;

  Chapter({
    this.id,
    required this.bookId,
    required this.idx,
    required this.title,
    this.url = '',
    required this.content,
    this.translated = '',
    this.translatedLang = '',
    int? addedAt,
  }) : addedAt = addedAt ?? nowMs();

  factory Chapter.fromMap(Map<String, Object?> m) => Chapter(
        id: m['id'] as int?,
        bookId: m['book_id'] as int,
        idx: m['idx'] as int,
        title: m['title'] as String? ?? '',
        url: m['url'] as String? ?? '',
        content: m['content'] as String? ?? '',
        translated: m['translated'] as String? ?? '',
        translatedLang: m['translated_lang'] as String? ?? '',
        addedAt: m['added_at'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'idx': idx,
        'title': title,
        'url': url,
        'content': content,
        'translated': translated,
        'translated_lang': translatedLang,
        'char_count': content.length,
        'added_at': addedAt,
      };
}

class Bookmark {
  int? id;
  int bookId, chapterId, para, createdAt;
  String snippet;
  Bookmark({this.id, required this.bookId, required this.chapterId, required this.para, required this.snippet, int? createdAt})
      : createdAt = createdAt ?? nowMs();

  factory Bookmark.fromMap(Map<String, Object?> m) => Bookmark(
        id: m['id'] as int?,
        bookId: m['book_id'] as int,
        chapterId: m['chapter_id'] as int,
        para: m['para'] as int,
        snippet: m['snippet'] as String? ?? '',
        createdAt: m['created_at'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'para': para,
        'snippet': snippet,
        'created_at': createdAt,
      };
}

/// A highlighted passage, optionally with a note. Offsets are within one paragraph.
class Quote {
  int? id;
  int bookId, chapterId, para, start, end, color, createdAt;
  String text, note;
  Quote({
    this.id,
    required this.bookId,
    required this.chapterId,
    required this.para,
    required this.start,
    required this.end,
    required this.text,
    this.note = '',
    this.color = 0,
    int? createdAt,
  }) : createdAt = createdAt ?? nowMs();

  factory Quote.fromMap(Map<String, Object?> m) => Quote(
        id: m['id'] as int?,
        bookId: m['book_id'] as int,
        chapterId: m['chapter_id'] as int,
        para: m['para'] as int,
        start: m['start'] as int,
        end: m['end'] as int,
        text: m['text'] as String? ?? '',
        note: m['note'] as String? ?? '',
        color: m['color'] as int? ?? 0,
        createdAt: m['created_at'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'chapter_id': chapterId,
        'para': para,
        'start': start,
        'end': end,
        'text': text,
        'note': note,
        'color': color,
        'created_at': createdAt,
      };
}

/// Personal glossary entry. [kind]: 0 = word, 1 = character, 2 = term.
class DictEntry {
  int? id;
  int kind, createdAt;
  String word, definition;
  DictEntry({this.id, required this.kind, required this.word, this.definition = '', int? createdAt})
      : createdAt = createdAt ?? nowMs();

  factory DictEntry.fromMap(Map<String, Object?> m) => DictEntry(
        id: m['id'] as int?,
        kind: m['kind'] as int? ?? 0,
        word: m['word'] as String? ?? '',
        definition: m['definition'] as String? ?? '',
        createdAt: m['created_at'] as int? ?? 0,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'kind': kind,
        'word': word,
        'definition': definition,
        'created_at': createdAt,
      };
}

class Shelf {
  final int id;
  final String name;
  final int count;
  Shelf(this.id, this.name, this.count);
}
