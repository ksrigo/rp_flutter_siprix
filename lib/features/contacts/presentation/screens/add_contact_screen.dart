import 'package:flutter/material.dart';

import '../widgets/contact_form.dart';

class AddContactScreen extends StatelessWidget {
  const AddContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ContactForm(
      onSaved: () => Navigator.of(context).pop(),
    );
  }
}