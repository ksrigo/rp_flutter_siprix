import 'package:flutter/material.dart';

import '../../data/models/contact_model.dart';
import '../widgets/contact_form.dart';

class EditContactScreen extends StatelessWidget {
  final ContactModel contact;

  const EditContactScreen({
    super.key,
    required this.contact,
  });

  @override
  Widget build(BuildContext context) {
    return ContactForm(
      contact: contact,
      onSaved: () => Navigator.of(context).pop(),
      onDeleted: () => Navigator.of(context).pop(),
    );
  }
}