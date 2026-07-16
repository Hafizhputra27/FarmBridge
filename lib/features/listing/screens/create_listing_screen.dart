import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/listing_repository.dart';
import 'listing_form.dart';

class CreateListingScreen extends StatefulWidget {
  final Map<String, dynamic>? listing;

  const CreateListingScreen({super.key, this.listing});

  bool get isEditing => listing != null;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _repo = ListingRepository();

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Listing' : 'Buat Listing Baru'),
      ),
      body: ListingForm(
        listing: widget.listing,
        buttonLabel: isEditing ? 'Save Changes' : 'Publish Listing',
        onSubmit: (data) async {
          if (isEditing) {
            await _repo.update(widget.listing!['id'], data);
          } else {
            await _repo.create(data);
          }
          if (!context.mounted) return;
          context.pop();
        },
      ),
    );
  }
}
