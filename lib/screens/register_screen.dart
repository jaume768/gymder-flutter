// lib/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String username = '';
  String firstName = '';
  String lastName = '';
  String gender = '';
  List<String> seeking = [];
  String relationshipGoal = '';
  bool isLoading = false;
  String errorMessage = '';

  final List<String> genders = [
    'Masculino',
    'Femenino',
    'No Binario',
    'Prefiero no decirlo',
    'Otro'
  ];
  final List<String> seekingOptions = [
    'Masculino',
    'Femenino',
    'No Binario',
    'Prefiero no decirlo',
    'Otro'
  ];
  final List<String> relationshipGoals = [
    'Amistad',
    'Relación',
    'Casual',
    'Otro'
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color.fromRGBO(64, 65, 65, 1), // Fondo gris
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(64, 65, 65, 1),
        elevation: 0,
        title: const Text('Registrarse'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Título
              const Text(
                'Crear Cuenta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Formulario
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Correo Electrónico
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu correo';
                        }
                        // Validar formato de correo
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(value)) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                      onSaved: (value) => email = value!,
                      cursorColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    // Contraseña
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu contraseña';
                        }
                        if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                      onSaved: (value) => password = value!,
                      cursorColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    // Username
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu username';
                        }
                        if (value.length < 3) {
                          return 'El username debe tener al menos 3 caracteres';
                        }
                        return null;
                      },
                      onSaved: (value) => username = value!,
                      cursorColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    // Nombre
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Nombre',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu nombre';
                        }
                        return null;
                      },
                      onSaved: (value) => firstName = value!,
                      cursorColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    // Apellido
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Apellido',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa tu apellido';
                        }
                        return null;
                      },
                      onSaved: (value) => lastName = value!,
                      cursorColor: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    // Género
                    DropdownButtonFormField<String>(
                      // El texto del ítem seleccionado será blanco (gracias a style y selectedItemBuilder).
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Género',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      value: gender.isNotEmpty ? gender : null,
                      hint: const Text(
                        'Seleccionar género',
                        style: TextStyle(color: Colors.white54),
                      ),
                      items: genders.map((g) {
                        return DropdownMenuItem(
                          value: g,
                          // Aquí las opciones se muestran en negro:
                          child: Text(
                            g,
                            style: const TextStyle(color: Colors.black),
                          ),
                        );
                      }).toList(),
                      // ¡Esta parte es la clave! Con selectedItemBuilder
                      // personalizamos cómo se muestra el ítem seleccionado:
                      selectedItemBuilder: (BuildContext context) {
                        return genders.map((String g) {
                          return Text(
                            g,
                            style: const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                      onChanged: (value) {
                        setState(() {
                          gender = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor selecciona tu género';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Buscando
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Buscando:',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10.0,
                      children: seekingOptions.map((option) {
                        return FilterChip(
                          label: Text(
                            option,
                            style: const TextStyle(color: Colors.black),
                          ),
                          selected: seeking.contains(option),
                          backgroundColor: Colors.white54,
                          selectedColor: Colors.white,
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                seeking.add(option);
                              } else {
                                seeking.remove(option);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Objetivo de Relación
                    DropdownButtonFormField<String>(
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        labelText: 'Objetivo de Relación',
                        labelStyle: const TextStyle(color: Colors.white),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white54),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        errorStyle: const TextStyle(color: Colors.redAccent),
                      ),
                      value: relationshipGoal.isNotEmpty ? relationshipGoal : null,
                      hint: const Text(
                        'Seleccionar objetivo de relación',
                        style: TextStyle(color: Colors.white54),
                      ),
                      items: relationshipGoals.map((goal) {
                        return DropdownMenuItem(
                          value: goal,
                          child: Text(
                            goal,
                            style: const TextStyle(color: Colors.black),
                          ),
                        );
                      }).toList(),
                      // De nuevo, definimos cómo se ve el ítem seleccionado
                      selectedItemBuilder: (BuildContext context) {
                        return relationshipGoals.map((String goal) {
                          return Text(
                            goal,
                            style: const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                      onChanged: (value) {
                        setState(() {
                          relationshipGoal = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor selecciona un objetivo de relación';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    // Botón de Registro
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                          if (_formKey.currentState!.validate()) {
                            if (seeking.isEmpty) {
                              setState(() {
                                errorMessage =
                                'Por favor selecciona al menos una opción en Buscando';
                              });
                              return;
                            }
                            _formKey.currentState!.save();
                            setState(() {
                              isLoading = true;
                              errorMessage = '';
                            });
                            final result = await authProvider.register(
                              email: email,
                              password: password,
                              username: username,
                              firstName: firstName,
                              lastName: lastName,
                              gender: gender,
                              seeking: seeking,
                              relationshipGoal: relationshipGoal,
                            );
                            setState(() {
                              isLoading = false;
                            });
                            if (result['message'] ==
                                'Usuario registrado con éxito') {
                              // Registro exitoso, redirigir al login
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Registro exitoso. Por favor inicia sesión.'),
                                ),
                              );
                              Navigator.pop(context);
                            } else {
                              setState(() {
                                errorMessage = result['message'] ??
                                    'Error al registrar';
                              });
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white, // Fondo blanco
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: isLoading
                            ? const CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.black),
                        )
                            : const Text(
                          'Registrarse',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Mensaje de Error
                    if (errorMessage.isNotEmpty)
                      Text(
                        errorMessage,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    // Opción para Iniciar Sesión
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes una cuenta?',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Text(
                            'Inicia Sesión',
                            style: TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
