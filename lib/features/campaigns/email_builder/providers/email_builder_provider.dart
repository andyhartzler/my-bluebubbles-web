import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';

class EmailBuilderProvider extends ChangeNotifier {
  EmailDocument _document = const EmailDocument();
  final List<EmailDocument> _history = [];
  int _historyIndex = -1;
  String? _selectedComponentId;
  String? _selectedSectionId;
  bool _isPreviewMode = false;
  String _previewDevice = 'desktop';

  EmailDocument get document => _document;
  String? get selectedComponentId => _selectedComponentId;
  String? get selectedSectionId => _selectedSectionId;
  bool get isPreviewMode => _isPreviewMode;
  String get previewDevice => _previewDevice;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  final _uuid = const Uuid();

  EmailBuilderProvider() {
    _saveToHistory();
  }

  void loadDocument(EmailDocument doc) {
    _document = doc;
    _history.clear();
    _historyIndex = -1;
    _saveToHistory();
    notifyListeners();
  }

  void addSection({int? index}) {
    final section = EmailSection(
      id: _uuid.v4(),
      columns: [
        EmailColumn(
          id: _uuid.v4(),
          flex: 1,
        ),
      ],
    );

    final sections = List<EmailSection>.from(_document.sections);
    if (index != null) {
      sections.insert(index, section);
    } else {
      sections.add(section);
    }

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void duplicateSection(String sectionId) {
    final sections = List<EmailSection>.from(_document.sections);
    final index = sections.indexWhere((s) => s.id == sectionId);
    if (index == -1) return;

    final original = sections[index];
    final duplicate = _duplicateSectionWithNewIds(original);
    sections.insert(index + 1, duplicate);

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void deleteSection(String sectionId) {
    final sections =
        _document.sections.where((s) => s.id != sectionId).toList();
    _document = _document.copyWith(sections: sections);
    if (_selectedSectionId == sectionId) {
      _selectedSectionId = null;
    }
    _saveToHistory();
    notifyListeners();
  }

  void moveSectionUp(String sectionId) {
    final sections = List<EmailSection>.from(_document.sections);
    final index = sections.indexWhere((s) => s.id == sectionId);
    if (index <= 0) return;

    final temp = sections[index];
    sections[index] = sections[index - 1];
    sections[index - 1] = temp;

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void moveSectionDown(String sectionId) {
    final sections = List<EmailSection>.from(_document.sections);
    final index = sections.indexWhere((s) => s.id == sectionId);
    if (index == -1 || index >= sections.length - 1) return;

    final temp = sections[index];
    sections[index] = sections[index + 1];
    sections[index + 1] = temp;

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void updateSectionStyle(String sectionId, SectionStyle style) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        return section.copyWith(style: style);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void addColumn(String sectionId) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = List<EmailColumn>.from(section.columns);
        columns.add(EmailColumn(id: _uuid.v4(), flex: 1));
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void deleteColumn(String sectionId, String columnId) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.where((c) => c.id != columnId).toList();
        if (columns.isEmpty) {
          return section;
        }
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void updateColumnFlex(String sectionId, String columnId, int flex) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            return column.copyWith(flex: flex);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void addComponent(
      String sectionId, String columnId, EmailComponent component) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = List<EmailComponent>.from(column.components);
            components.add(component);
            return column.copyWith(components: components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void updateComponent(
      String sectionId, String columnId, EmailComponent component) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = column.components.map((c) {
              return c.when(
                text: (id, content, style) =>
                    id == component.id ? component : c,
                image: (id, url, alt, link, style) =>
                    id == component.id ? component : c,
                button: (id, text, url, style) =>
                    id == component.id ? component : c,
                divider: (id, style) => id == component.id ? component : c,
                spacer: (id, height) => id == component.id ? component : c,
                social: (id, links, style) =>
                    id == component.id ? component : c,
              );
            }).toList();
            return column.copyWith(components: components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    _saveToHistory();
    notifyListeners();
  }

  void deleteComponent(String sectionId, String columnId, String componentId) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = column.components.where((c) {
              return c.when(
                text: (id, _, __) => id != componentId,
                image: (id, _, __, ___, ____) => id != componentId,
                button: (id, _, __, ___) => id != componentId,
                divider: (id, _) => id != componentId,
                spacer: (id, _) => id != componentId,
                social: (id, _, __) => id != componentId,
              );
            }).toList();
            return column.copyWith(components: components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    if (_selectedComponentId == componentId) {
      _selectedComponentId = null;
    }
    _saveToHistory();
    notifyListeners();
  }

  void moveComponent(
    String fromSectionId,
    String fromColumnId,
    String toSectionId,
    String toColumnId,
    String componentId,
    int toIndex,
  ) {
    EmailComponent? movedComponent;
    final sections = _document.sections.map((section) {
      if (section.id == fromSectionId) {
        final columns = section.columns.map((column) {
          if (column.id == fromColumnId) {
            final components = List<EmailComponent>.from(column.components);
            final index = components.indexWhere((c) => c.when(
                  text: (id, _, __) => id == componentId,
                  image: (id, _, __, ___, ____) => id == componentId,
                  button: (id, _, __, ___) => id == componentId,
                  divider: (id, _) => id == componentId,
                  spacer: (id, _) => id == componentId,
                  social: (id, _, __) => id == componentId,
                ));
            if (index != -1) {
              movedComponent = components.removeAt(index);
            }
            return column.copyWith(components: components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    if (movedComponent == null) return;

    final finalSections = sections.map((section) {
      if (section.id == toSectionId) {
        final columns = section.columns.map((column) {
          if (column.id == toColumnId) {
            final components = List<EmailComponent>.from(column.components);
            components.insert(
                toIndex.clamp(0, components.length), movedComponent!);
            return column.copyWith(components: components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: finalSections);
    _saveToHistory();
    notifyListeners();
  }

  void selectComponent(String componentId) {
    _selectedComponentId = componentId;
    notifyListeners();
  }

  void selectSection(String sectionId) {
    _selectedSectionId = sectionId;
    _selectedComponentId = null;
    notifyListeners();
  }

  void clearSelection() {
    _selectedComponentId = null;
    _selectedSectionId = null;
    notifyListeners();
  }

  void togglePreviewMode() {
    _isPreviewMode = !_isPreviewMode;
    notifyListeners();
  }

  void setPreviewDevice(String device) {
    _previewDevice = device;
    notifyListeners();
  }

  void _saveToHistory() {
    _historyIndex++;
    if (_historyIndex < _history.length) {
      _history.removeRange(_historyIndex, _history.length);
    }
    _history.add(_document);

    if (_history.length > 50) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _document = _history[_historyIndex];
      notifyListeners();
    }
  }

  void redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _document = _history[_historyIndex];
      notifyListeners();
    }
  }

  EmailSection _duplicateSectionWithNewIds(EmailSection section) {
    final newColumns = section.columns.map((column) {
      final newComponents = column.components.map((component) {
        return component.when(
          text: (_, content, style) => EmailComponent.text(
            id: _uuid.v4(),
            content: content,
            style: style,
          ),
          image: (_, url, alt, link, style) => EmailComponent.image(
            id: _uuid.v4(),
            url: url,
            alt: alt,
            link: link,
            style: style,
          ),
          button: (_, text, url, style) => EmailComponent.button(
            id: _uuid.v4(),
            text: text,
            url: url,
            style: style,
          ),
          divider: (_, style) => EmailComponent.divider(
            id: _uuid.v4(),
            style: style,
          ),
          spacer: (_, height) => EmailComponent.spacer(
            id: _uuid.v4(),
            height: height,
          ),
          social: (_, links, style) => EmailComponent.social(
            id: _uuid.v4(),
            links: links,
            style: style,
          ),
        );
      }).toList();

      return EmailColumn(
        id: _uuid.v4(),
        flex: column.flex,
        components: newComponents,
        style: column.style,
      );
    }).toList();

    return EmailSection(
      id: _uuid.v4(),
      columns: newColumns,
      style: section.style,
    );
  }
}
