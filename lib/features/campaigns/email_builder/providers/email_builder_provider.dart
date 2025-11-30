import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/email_component.dart';
import '../models/email_document.dart';

class EmailBuilderProvider extends ChangeNotifier {
  EmailDocument _document;
  final List<EmailDocument> _history = [];
  int _historyIndex = -1;
  String? _selectedComponentId;
  String? _selectedSectionId;
  String? _hoveredSectionId;
  String? _hoveredColumnId;
  String? _hoveredComponentId;
  bool _isPreviewMode = false;
  String _previewDevice = 'desktop';
  double _zoomLevel = 1.0;


  EmailDocument get document => _document;
  String? get selectedComponentId => _selectedComponentId;
  String? get selectedSectionId => _selectedSectionId;
  String? get hoveredSectionId => _hoveredSectionId;
  String? get hoveredColumnId => _hoveredColumnId;
  String? get hoveredComponentId => _hoveredComponentId;
  bool get isPreviewMode => _isPreviewMode;
  String get previewDevice => _previewDevice;
  double get zoomLevel => _zoomLevel;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  ({EmailSection section, EmailColumn column, EmailComponent component})?
      findComponentById(String componentId) {
    for (final section in _document.sections) {
      for (final column in section.columns) {
        for (final component in column.components) {
          final id = component.when(
            text: (id, _, __) => id,
            image: (id, _, __, ___, ____) => id,
            button: (id, _, __, ___) => id,
            divider: (id, _) => id,
            spacer: (id, _) => id,
            social: (id, _, __) => id,
            avatar: (id, _, __, ___) => id,
            heading: (id, _, __) => id,
            html: (id, _, __) => id,
            container: (id, _, __) => id,
          );

          if (id == componentId) {
            return (section: section, column: column, component: component);
          }
        }
      }
    }

    return null;
  }

  final _uuid = const Uuid();

  EmailBuilderProvider({EmailDocument? initialDocument})
      : _document = initialDocument ?? EmailDocument.empty() {
    _saveToHistory();
  }

  void loadDocument(EmailDocument doc) {
    _document = doc;
    _history.clear();
    _historyIndex = -1;
    _saveToHistory();
    _selectedComponentId = null;
    _selectedSectionId = null;
    _hoveredSectionId = null;
    _hoveredColumnId = null;
    _hoveredComponentId = null;
    notifyListeners();
  }

  void updateDocument(EmailDocument doc) {
    _document = doc;
    _saveToHistory();
    notifyListeners();
  }

  void updateMetadata({Map<String, dynamic>? theme, DateTime? lastModified}) {
    _document = _document.copyWith(
      theme: theme ?? _document.theme,
      lastModified: lastModified ?? DateTime.now(),
    );
    _saveToHistory();
    notifyListeners();
  }

  void updateStyles(EmailSettings settings) {
    _document = _document.copyWith(settings: settings);
    _saveToHistory();
    notifyListeners();
  }

  EmailSection addSection({int? index}) {
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
    return section;
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

  void updateColumnStyle(String sectionId, String columnId, ColumnStyle style) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            return column.copyWith(style: style);
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
    insertComponent(sectionId, columnId, component, null);
  }

  void insertComponent(String sectionId, String columnId,
      EmailComponent component, int? index) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = List<EmailComponent>.from(column.components);
            if (index != null &&
                index >= 0 &&
                index <= components.length) {
              components.insert(index, component);
            } else {
              components.add(component);
            }
            return column.copyWith(components: components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    _selectedComponentId = _componentId(component);
    _saveToHistory();
    notifyListeners();
  }

  void updateBlock(
    String sectionId,
    String columnId,
    EmailComponent component,
  ) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = _replaceComponent(
              column.components,
              component,
            );
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
    String sectionId,
    String columnId,
    EmailComponent component,
  ) {
    updateBlock(sectionId, columnId, component);
  }

  void deleteBlock(String sectionId, String columnId, String componentId) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components =
                _removeComponent(column.components, componentId).components;
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
    if (_hoveredComponentId == componentId) {
      clearHover();
    }
    _saveToHistory();
    notifyListeners();
  }

  void deleteComponent(String sectionId, String columnId, String componentId) {
    deleteBlock(sectionId, columnId, componentId);
  }

  void moveBlock(
    String fromSectionId,
    String fromColumnId,
    String toSectionId,
    String toColumnId,
    String componentId,
    int toIndex,
  ) {
    EmailComponent? movedComponent;
    final sectionsWithoutComponent = _document.sections.map((section) {
      if (section.id == fromSectionId) {
        final columns = section.columns.map((column) {
          if (column.id == fromColumnId) {
            final removalResult = _removeComponent(column.components, componentId);
            movedComponent = removalResult.removed;
            return column.copyWith(components: removalResult.components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    if (movedComponent == null) return;

    final finalSections = sectionsWithoutComponent.map((section) {
      if (section.id == toSectionId) {
        final columns = section.columns.map((column) {
          if (column.id == toColumnId) {
            final components = List<EmailComponent>.from(column.components);
            components.insert(toIndex.clamp(0, components.length), movedComponent!);
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

  void moveComponent(
    String fromSectionId,
    String fromColumnId,
    String toSectionId,
    String toColumnId,
    String componentId,
    int toIndex,
  ) {
    moveBlock(
      fromSectionId,
      fromColumnId,
      toSectionId,
      toColumnId,
      componentId,
      toIndex,
    );
  }

  void duplicateComponent(
    String sectionId,
    String columnId,
    String componentId,
  ) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = List<EmailComponent>.from(column.components);
            final index = components.indexWhere((component) => component.when(
                  text: (id, _, __) => id == componentId,
                  image: (id, _, __, ___, ____) => id == componentId,
                  button: (id, _, __, ___) => id == componentId,
                  divider: (id, _) => id == componentId,
                  spacer: (id, _) => id == componentId,
                  social: (id, _, __) => id == componentId,
                  avatar: (id, _, __, ___) => id == componentId,
                  heading: (id, _, __) => id == componentId,
                  html: (id, _, __) => id == componentId,
                  container: (id, _, __) => id == componentId,
                ));

            if (index != -1) {
              final duplicated = _duplicateComponentWithNewIds(components[index]);
              components.insert(index + 1, duplicated);
            }

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

  void selectComponent(String componentId) {
    _selectedComponentId = componentId;
    notifyListeners();
  }

  void selectSection(String sectionId) {
    _selectedSectionId = sectionId;
    _selectedComponentId = null;
    notifyListeners();
  }

  void selectBlock(String? componentId, {String? sectionId}) {
    _selectedComponentId = componentId;
    if (sectionId != null) {
      _selectedSectionId = sectionId;
    }
    notifyListeners();
  }

  void hoverBlock({String? sectionId, String? columnId, String? componentId}) {
    final hasChanges = _hoveredSectionId != sectionId ||
        _hoveredColumnId != columnId ||
        _hoveredComponentId != componentId;

    if (!hasChanges) return;

    _hoveredSectionId = sectionId;
    _hoveredColumnId = columnId;
    _hoveredComponentId = componentId;
    notifyListeners();
  }

  void clearSelection() {
    _selectedComponentId = null;
    _selectedSectionId = null;
    notifyListeners();
  }

  void clearHover() {
    _hoveredSectionId = null;
    _hoveredColumnId = null;
    _hoveredComponentId = null;
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

  void setZoomLevel(double zoom) {
    _zoomLevel = zoom.clamp(0.5, 2.0);
    notifyListeners();
  }

  void addSectionWithLayout(List<int> columnFlexValues, {int? index}) {
    final columns = columnFlexValues.map((flex) {
      return EmailColumn(
        id: _uuid.v4(),
        flex: flex,
      );
    }).toList();

    final section = EmailSection(
      id: _uuid.v4(),
      columns: columns,
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

  void _saveToHistory() {
    _document = _document.copyWith(lastModified: DateTime.now());

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(_document);
    _historyIndex = _history.length - 1;

    if (_history.length > 50) {
      _history.removeAt(0);
      _historyIndex--;
    }
  }

  void pushSnapshot({bool notify = false}) {
    _saveToHistory();
    if (notify) {
      this.notifyListeners();
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

  @override
  void dispose() {
    _history.clear();
    super.dispose();
  }

  String _componentId(EmailComponent component) {
    return component.when(
      text: (id, _, __) => id,
      image: (id, _, __, ___, ____) => id,
      button: (id, _, __, ___) => id,
      divider: (id, _) => id,
      spacer: (id, _) => id,
      social: (id, _, __) => id,
      avatar: (id, _, __, ___) => id,
      heading: (id, _, __) => id,
      html: (id, _, __) => id,
      container: (id, _, __) => id,
    );
  }

  List<EmailComponent> _replaceComponent(
    List<EmailComponent> components,
    EmailComponent replacement,
  ) {
    final replacementId = _componentId(replacement);

    return components.map((component) {
      final id = _componentId(component);
      if (id == replacementId) {
        return replacement;
      }

      if (component is ContainerComponent) {
        final updatedChildren = _replaceComponent(
          component.children,
          replacement,
        );

        if (!identical(updatedChildren, component.children)) {
          return component.copyWith(children: updatedChildren);
        }
      }

      return component;
    }).toList();
  }

  _RemovalResult _removeComponent(
    List<EmailComponent> components,
    String componentId,
  ) {
    final updated = <EmailComponent>[];
    EmailComponent? removed;

    for (final component in components) {
      final id = _componentId(component);
      if (id == componentId) {
        removed = component;
        continue;
      }

      if (component is ContainerComponent) {
        final nestedResult = _removeComponent(component.children, componentId);
        if (nestedResult.removed != null) {
          removed = nestedResult.removed;
          updated.add(component.copyWith(children: nestedResult.components));
          continue;
        }
      }

      updated.add(component);
    }

    return _RemovalResult(components: updated, removed: removed);
  }

  EmailComponent _duplicateComponent(EmailComponent component) {
    return _duplicateComponentWithNewIds(component);
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
          avatar: (_, imageUrl, alt, style) => EmailComponent.avatar(
            id: _uuid.v4(),
            imageUrl: imageUrl,
            alt: alt,
            style: style,
          ),
          heading: (_, content, style) => EmailComponent.heading(
            id: _uuid.v4(),
            content: content,
            style: style,
          ),
          html: (_, htmlContent, style) => EmailComponent.html(
            id: _uuid.v4(),
            htmlContent: htmlContent,
            style: style,
          ),
          container: (_, children, style) => EmailComponent.container(
            id: _uuid.v4(),
            children: children.map(_duplicateComponent).toList(),
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

  EmailComponent _duplicateComponentWithNewIds(EmailComponent component) {
    return component.when(
      text: (_, content, style) =>
          EmailComponent.text(id: _uuid.v4(), content: content, style: style),
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
      divider: (_, style) =>
          EmailComponent.divider(id: _uuid.v4(), style: style),
      spacer: (_, height) =>
          EmailComponent.spacer(id: _uuid.v4(), height: height),
      social: (_, links, style) =>
          EmailComponent.social(id: _uuid.v4(), links: links, style: style),
      avatar: (_, imageUrl, alt, style) => EmailComponent.avatar(
        id: _uuid.v4(),
        imageUrl: imageUrl,
        alt: alt,
        style: style,
      ),
      heading: (_, content, style) => EmailComponent.heading(
        id: _uuid.v4(),
        content: content,
        style: style,
      ),
      html: (_, htmlContent, style) => EmailComponent.html(
        id: _uuid.v4(),
        htmlContent: htmlContent,
        style: style,
      ),
      container: (_, children, style) => EmailComponent.container(
        id: _uuid.v4(),
        children:
            children.map((child) => _duplicateComponentWithNewIds(child)).toList(),
        style: style,
      ),
    );
  }
}

class _RemovalResult {
  final List<EmailComponent> components;
  final EmailComponent? removed;

  const _RemovalResult({required this.components, this.removed});
}
