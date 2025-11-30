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

  final _uuid = const Uuid();

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

  EmailComponent? get activeBlock =>
      _selectedComponentId != null ? _findComponentById(_selectedComponentId!) : null;
  EmailComponent? get hoveredBlock =>
      _hoveredComponentId != null ? _findComponentById(_hoveredComponentId!) : null;
  EmailSection? get activeSection =>
      _selectedSectionId != null ? _findSectionById(_selectedSectionId!) : null;
  EmailSection? get hoveredSection =>
      _hoveredSectionId != null ? _findSectionById(_hoveredSectionId!) : null;

  /// A document is considered valid if there is at least one section with
  /// columns and at least one component ready for export.
  bool get canSave => _document.sections.any(
        (section) => section.columns.any(
              (column) => column.components.isNotEmpty,
            ),
      );
  bool get canExport => canSave;

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

  void addBlock(
    String sectionId,
    String columnId,
    EmailComponent component, {
    int? index,
  }) {
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = List<EmailComponent>.from(column.components);
            final insertIndex =
                index != null ? index.clamp(0, components.length) : components.length;
            components.insert(insertIndex, component);
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

  void duplicateBlock(String sectionId, String columnId, String componentId) {
    EmailComponent? duplicatedComponent;
    final sections = _document.sections.map((section) {
      if (section.id == sectionId) {
        final columns = section.columns.map((column) {
          if (column.id == columnId) {
            final components = List<EmailComponent>.from(column.components);
            final index = components
                .indexWhere((component) => _componentId(component) == componentId);
            if (index == -1) return column;

            duplicatedComponent = _duplicateComponent(components[index]);
            components.insert(index + 1, duplicatedComponent!);
            return column.copyWith(components: components);
          }
          return column;
        }).toList();
        return section.copyWith(columns: columns);
      }
      return section;
    }).toList();

    _document = _document.copyWith(sections: sections);
    if (duplicatedComponent != null) {
      _selectedComponentId = _componentId(duplicatedComponent!);
    }
    _saveToHistory();
    notifyListeners();
  }

  void addComponent(
      String sectionId, String columnId, EmailComponent component) {
    addBlock(sectionId, columnId, component);
  }

  void updateComponent(
      String sectionId, String columnId, EmailComponent component) {
    updateBlock(sectionId, columnId, component);
  }

  void deleteComponent(String sectionId, String columnId, String componentId) {
    deleteBlock(sectionId, columnId, componentId);
  }

  void moveComponent(
    String fromSectionId,
    String fromColumnId,
    String toSectionId,
    String toColumnId,
    String componentId,
    int toIndex,
  ) {
    moveBlock(fromSectionId, fromColumnId, toSectionId, toColumnId, componentId,
        toIndex);
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

  EmailSection? _findSectionById(String sectionId) {
    try {
      return _document.sections.firstWhere((section) => section.id == sectionId);
    } catch (_) {
      return null;
    }
  }

  EmailComponent? _findComponentById(String componentId) {
    for (final section in _document.sections) {
      for (final column in section.columns) {
        final found = _findComponentInList(column.components, componentId);
        if (found != null) return found;
      }
    }
    return null;
  }

  EmailComponent? _findComponentInList(
      List<EmailComponent> components, String componentId) {
    for (final component in components) {
      if (_componentId(component) == componentId) return component;
      if (component is ContainerComponent) {
        final nested = _findComponentInList(component.children, componentId);
        if (nested != null) return nested;
      }
    }
    return null;
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
    EmailComponent updated,
  ) {
    final updatedId = _componentId(updated);
    return components.map((component) {
      if (_componentId(component) == updatedId) {
        return updated;
      }
      if (component is ContainerComponent) {
        final updatedChildren = _replaceComponent(component.children, updated);
        if (updatedChildren != component.children) {
          return component.copyWith(children: updatedChildren);
        }
      }
      return component;
    }).toList();
  }

  _ComponentRemovalResult _removeComponent(
    List<EmailComponent> components,
    String componentId,
  ) {
    final updatedComponents = <EmailComponent>[];
    EmailComponent? removedComponent;

    for (final component in components) {
      if (_componentId(component) == componentId) {
        removedComponent = component;
        continue;
      }

      if (component is ContainerComponent) {
        final nestedResult = _removeComponent(component.children, componentId);
        if (nestedResult.removed != null && removedComponent == null) {
          removedComponent = nestedResult.removed;
        }
        updatedComponents
            .add(component.copyWith(children: nestedResult.components));
        continue;
      }

      updatedComponents.add(component);
    }

    return _ComponentRemovalResult(updatedComponents, removedComponent);
  }

  EmailComponent _duplicateComponent(EmailComponent component) {
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
  }
}

class _ComponentRemovalResult {
  final List<EmailComponent> components;
  final EmailComponent? removed;

  const _ComponentRemovalResult(this.components, this.removed);
}
