import 'package:flutter/material.dart';

/// View-mode presentation options for the Candidates page list panel.
enum CandidateViewMode {
  list,
  grid,
  table,
  ydPrimary,
}

extension CandidateViewModeX on CandidateViewMode {
  String get label {
    switch (this) {
      case CandidateViewMode.list:
        return 'List';
      case CandidateViewMode.grid:
        return 'Grid';
      case CandidateViewMode.table:
        return 'Table';
      case CandidateViewMode.ydPrimary:
        return 'Young Dems';
    }
  }

  IconData get icon {
    switch (this) {
      case CandidateViewMode.list:
        return Icons.view_list;
      case CandidateViewMode.grid:
        return Icons.grid_view;
      case CandidateViewMode.table:
        return Icons.table_rows;
      case CandidateViewMode.ydPrimary:
        return Icons.star;
    }
  }
}
