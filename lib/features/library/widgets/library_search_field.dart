import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/text_utils.dart';
import '../library_controller.dart';

/// Équivalent du champ `#searchInput` : recherche instantanée avec
/// direction de texte dynamique (adjustSearchDirection()).
class LibrarySearchField extends StatefulWidget {
  const LibrarySearchField({super.key});

  @override
  State<LibrarySearchField> createState() => _LibrarySearchFieldState();
}

class _LibrarySearchFieldState extends State<LibrarySearchField> {
  final _controller = TextEditingController();
  TextDirection _direction = TextDirection.rtl;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si la recherche a été effacée depuis l'extérieur (ex. bouton
    // "Localiser dans la bibliothèque", qui ferme la recherche pour
    // laisser place à l'onglet/groupe ciblé), le champ local doit suivre
    // — sinon il resterait rempli alors que la recherche n'est plus
    // active côté contrôleur.
    final searchQuery = context.select<LibraryController, String>((c) => c.searchQuery);
    if (searchQuery.isEmpty && _controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text.isNotEmpty) {
          setState(() => _controller.clear());
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _controller,
        textDirection: _direction,
        decoration: InputDecoration(
          hintText: 'Rechercher un livre...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    context.read<LibraryController>().clearSearch();
                    setState(() {});
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
        ),
        onChanged: (value) {
          setState(() => _direction = TextUtils.directionForInput(value));
          context.read<LibraryController>().search(value);
        },
      ),
    );
  }
}
