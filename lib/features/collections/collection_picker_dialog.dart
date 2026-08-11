import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../data/local/collections_repository.dart';
import '../../data/models/collection.dart';

/// Résultat du choix de l'utilisateur : collection existante sélectionnée
/// ou nouvellement créée.
class CollectionChoice {
  final int collectionId;
  final String collectionTitle;
  const CollectionChoice(this.collectionId, this.collectionTitle);
}

/// Équivalent de promptUserForCollection() : demande dans quelle collection
/// ranger un livre au moment de son téléchargement (avec possibilité d'en
/// créer une nouvelle à la volée).
Future<CollectionChoice?> showCollectionPickerDialog(
  BuildContext context, {
  required String bookTitle,
}) {
  return showDialog<CollectionChoice>(
    context: context,
    builder: (ctx) => _CollectionPickerDialog(bookTitle: bookTitle),
  );
}

class _CollectionPickerDialog extends StatefulWidget {
  final String bookTitle;
  const _CollectionPickerDialog({required this.bookTitle});

  @override
  State<_CollectionPickerDialog> createState() => _CollectionPickerDialogState();
}

class _CollectionPickerDialogState extends State<_CollectionPickerDialog> {
  List<BookCollection> _collections = [];
  int? _selectedId;
  bool _loading = true;
  bool _creatingNew = false;
  final _newTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newTitleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<CollectionsRepository>();
    final list = await repo.getAllCollections();
    setState(() {
      _collections = list;
      _selectedId = list.isNotEmpty
          ? (list.any((c) => c.id == AppConstants.defaultCollectionId)
              ? AppConstants.defaultCollectionId
              : list.first.id)
          : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Télécharger "${widget.bookTitle}"'),
      content: _loading
          ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
          : SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choisissez une collection :'),
                  const SizedBox(height: 8),
                  ..._collections.map(
                    (c) => RadioListTile<int>(
                      value: c.id,
                      // ignore: deprecated_member_use
                      groupValue: _selectedId,
                      dense: true,
                      title: Text(c.title),
                      // ignore: deprecated_member_use
                      onChanged: (value) => setState(() {
                        _selectedId = value;
                        _creatingNew = false;
                      }),
                    ),
                  ),
                  RadioListTile<int>(
                    value: -1,
                    // ignore: deprecated_member_use
                    groupValue: _creatingNew ? -1 : _selectedId,
                    dense: true,
                    title: const Text('Nouvelle collection...'),
                    // ignore: deprecated_member_use
                    onChanged: (_) => setState(() => _creatingNew = true),
                  ),
                  if (_creatingNew)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: TextField(
                        controller: _newTitleController,
                        autofocus: true,
                        decoration: const InputDecoration(hintText: 'Nom de la collection'),
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: _loading ? null : _confirm, child: const Text('Télécharger')),
      ],
    );
  }

  Future<void> _confirm() async {
    final repo = context.read<CollectionsRepository>();

    if (_creatingNew) {
      final title = _newTitleController.text.trim();
      if (title.isEmpty) return;
      final id = await repo.createCollection(title);
      if (mounted) Navigator.pop(context, CollectionChoice(id, title));
      return;
    }

    if (_selectedId == null) return;
    final collection = _collections.firstWhere((c) => c.id == _selectedId);
    if (mounted) Navigator.pop(context, CollectionChoice(collection.id, collection.title));
  }
}
