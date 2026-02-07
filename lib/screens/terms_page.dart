import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';

class TermsPage extends StatefulWidget {
  final bool isViewOnly; // Si es true, es solo lectura (Ajustes). Si es false, es obligatorio (Login).

  const TermsPage({super.key, this.isViewOnly = false});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _canAccept = false; // Se activa al llegar al final del texto

  @override
  void initState() {
    super.initState();
    // Detector de scroll para asegurar que el usuario baje
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
        if (!_canAccept) {
          setState(() => _canAccept = true);
        }
      }
    });
  }

  Future<void> _acceptTerms() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Guardar la aceptación con fecha y versión
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'accepted_terms': true,
          'terms_accepted_at': FieldValue.serverTimestamp(),
          'terms_version': '2.0_FULL', // Versión actualizada
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
                (route) => false,
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error de conexión: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Términos Legales", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        automaticallyImplyLeading: widget.isViewOnly,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ÁREA DE TEXTO LEGAL
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TÉRMINOS Y CONDICIONES DE USO",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "Última actualización: 06 de Febrero de 2026",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Divider(color: Colors.white24, height: 30),

                  _buildSectionTitle("1. INTRODUCCIÓN Y ACEPTACIÓN"),
                  _buildParagraph(
                      "Bienvenido a Nutri_IA (la 'Aplicación'). Al descargar, instalar o utilizar esta Aplicación, usted acepta estar legalmente vinculado por estos Términos y Condiciones. Si no está de acuerdo con alguno de estos términos, debe abstenerse de utilizar la Aplicación inmediatamente."
                  ),

                  _buildSectionTitle("2. DESCARGO DE RESPONSABILIDAD MÉDICA (IMPORTANTE)"),
                  _buildParagraph(
                      "LA APLICACIÓN Y SUS SERVICIOS NO CONSTITUYEN ASESORAMIENTO MÉDICO.\n\n"
                          "Nutri_IA utiliza algoritmos de inteligencia artificial para proporcionar estimaciones nutricionales y sugerencias de comidas. Esta información es meramente informativa y NO sustituye el consejo, diagnóstico o tratamiento de un profesional de la salud.\n\n"
                          "Usted reconoce que el uso de la información proporcionada por la IA es bajo su propio riesgo. Nunca debe ignorar el consejo médico profesional ni demorar en buscarlo debido a algo que haya leído en esta Aplicación. Si tiene una condición médica (diabetes, trastornos alimenticios, embarazo, etc.), consulte a su médico antes de usar esta Aplicación."
                  ),

                  _buildSectionTitle("3. EXACTITUD DE LA INTELIGENCIA ARTIFICIAL"),
                  _buildParagraph(
                      "Nutri_IA utiliza modelos de lenguaje avanzados (como Google Gemini) para analizar imágenes y textos. Usted comprende y acepta que:\n"
                          "A. La IA puede cometer errores, 'alucinar' datos o identificar incorrectamente alimentos.\n"
                          "B. Los valores de calorías y macronutrientes son estimaciones aproximadas y pueden variar significativamente de la realidad.\n"
                          "C. El Desarrollador no garantiza la exactitud, integridad o utilidad de ninguna respuesta generada por la IA."
                  ),

                  _buildSectionTitle("4. CUENTAS DE USUARIO Y SEGURIDAD"),
                  _buildParagraph(
                      "Para acceder a ciertas funciones, debe crear una cuenta. Usted es responsable de mantener la confidencialidad de su contraseña y de toda la actividad que ocurra bajo su cuenta. Nos reservamos el derecho de suspender o eliminar su cuenta si detectamos actividad sospechosa, fraudulenta o que viole estos términos."
                  ),

                  _buildSectionTitle("5. NORMAS DE LA COMUNIDAD Y CONTENIDO DE USUARIO"),
                  _buildParagraph(
                      "La Aplicación incluye funciones sociales (Muro de la Comunidad). Al publicar contenido, usted garantiza que posee los derechos sobre el mismo. Queda estrictamente prohibido publicar:\n"
                          "- Contenido ilegal, pornográfico, violento o que incite al odio.\n"
                          "- Información médica falsa o engañosa.\n"
                          "- Publicidad no autorizada (Spam).\n\n"
                          "Nos reservamos el derecho de eliminar cualquier contenido y banear a usuarios que violen estas normas sin previo aviso."
                  ),

                  _buildSectionTitle("6. SUSCRIPCIONES, PAGOS Y REEMBOLSOS"),
                  _buildParagraph(
                      "Nutri_IA puede ofrecer funciones 'Premium' o 'VIP' a cambio de una donación o pago. Usted acepta que estos pagos son voluntarios y tienen como fin apoyar el desarrollo.\n\n"
                          "Dada la naturaleza de los bienes digitales, los pagos NO SON REEMBOLSABLES, salvo que la legislación local aplicable exija lo contrario. El estado VIP no garantiza un tiempo de actividad del 100% del servicio."
                  ),

                  _buildSectionTitle("7. PROPIEDAD INTELECTUAL"),
                  _buildParagraph(
                      "El código fuente, diseño, interfaz y logotipos de Nutri_IA son propiedad exclusiva del Desarrollador. Se le otorga una licencia limitada, no exclusiva y revocable para uso personal y no comercial."
                  ),

                  _buildSectionTitle("8. LIMITACIÓN DE RESPONSABILIDAD"),
                  _buildParagraph(
                      "En la medida máxima permitida por la ley, el Desarrollador no será responsable de daños directos, indirectos, incidentales o consecuentes (incluyendo daños por pérdida de datos, lesiones personales o deterioro de salud) que surjan del uso o la imposibilidad de uso de la Aplicación."
                  ),

                  _buildSectionTitle("9. MODIFICACIONES"),
                  _buildParagraph(
                      "Podemos actualizar estos términos en cualquier momento. El uso continuado de la Aplicación después de dichos cambios constituye su aceptación de los nuevos términos."
                  ),

                  const SizedBox(height: 50),
                  const Center(child: Text("Fin del documento legal", style: TextStyle(color: Colors.grey, fontSize: 10))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // BOTÓN DE ACEPTACIÓN
          if (!widget.isViewOnly)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_canAccept)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.arrow_downward, color: Colors.grey, size: 14),
                          SizedBox(width: 5),
                          Text("Lee hasta el final para aceptar", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      // El botón se habilita solo si bajó el scroll (_canAccept) O si decides quitar esa restricción
                      onPressed: (_isLoading || !_canAccept) ? null : _acceptTerms,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FF88),
                        disabledBackgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Text(
                        _canAccept ? "HE LEÍDO Y ACEPTO" : "LEER TÉRMINOS...",
                        style: TextStyle(
                            color: _canAccept ? Colors.black : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 16
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // WIDGETS AUXILIARES PARA FORMATO
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 25, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00FF88), // Verde Neon
          fontSize: 15,
          fontWeight: FontWeight.w900, // Extra bold
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        height: 1.6, // Mayor espaciado para lectura fácil
      ),
    );
  }
}