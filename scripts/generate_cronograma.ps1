# Generador del cronograma de VitoStoreApp en Excel
# Cronograma: Septiembre - Noviembre 2026
# Crea un archivo .xlsx con formato profesional

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

$workbook = $excel.Workbooks.Add()
$sheet = $workbook.Worksheets.Item(1)
$sheet.Name = "Cronograma"

# ============================================================
# TITULO
# ============================================================
$sheet.Range("A1:H1").Merge()
$sheet.Cells.Item(1, 1).Value2 = "CRONOGRAMA DEL PROYECTO - VitoStoreApp"
$sheet.Cells.Item(1, 1).Font.Size = 16
$sheet.Cells.Item(1, 1).Font.Bold = $true
$sheet.Cells.Item(1, 1).Font.Color = 16777215
$sheet.Cells.Item(1, 1).Interior.Color = 6710932
$sheet.Cells.Item(1, 1).HorizontalAlignment = -4108
$sheet.Cells.Item(1, 1).VerticalAlignment = -4108
$sheet.Rows.Item(1).RowHeight = 35

# Subtitulo
$sheet.Range("A2:H2").Merge()
$sheet.Cells.Item(2, 1).Value2 = "Aplicacion Movil iOS/Android para VITO Technologies | Alumno: Norberto Suaste Hernandez | al03088785@tecmilenio.mx"
$sheet.Cells.Item(2, 1).Font.Size = 10
$sheet.Cells.Item(2, 1).Font.Italic = $true
$sheet.Cells.Item(2, 1).Font.Color = 3355443
$sheet.Cells.Item(2, 1).HorizontalAlignment = -4108
$sheet.Rows.Item(2).RowHeight = 22

# ============================================================
# ENCABEZADOS DE COLUMNAS
# ============================================================
$headers = @("Fase", "Tarea", "Descripcion", "Fecha Inicio", "Fecha Fin", "Duracion (dias)", "Responsable", "Estado")

for ($col = 0; $col -lt $headers.Count; $col++) {
    $cell = $sheet.Cells.Item(4, $col + 1)
    $cell.Value2 = $headers[$col]
    $cell.Font.Bold = $true
    $cell.Font.Size = 11
    $cell.Font.Color = 16777215
    $cell.Interior.Color = 6710932
    $cell.HorizontalAlignment = -4108
    $cell.VerticalAlignment = -4108
    $cell.Borders.LineStyle = 1
    $cell.Borders.Color = 0
}
$sheet.Rows.Item(4).RowHeight = 28

# ============================================================
# DATOS DEL CRONOGRAMA — Septiembre a Noviembre 2026
# Concordancia cronologica: cada fase empieza cuando termina la anterior
# ============================================================
$data = @(
    # FASE 0 - Scaffold y arquitectura base (Sep 1 - Sep 7)
    @("Fase 0", "Scaffold del proyecto Flutter", "Creacion de estructura de carpetas, pubspec.yaml, tema AppColors/AppTheme", "01/09/2026", "02/09/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 0", "Capa de red (Dio + interceptores)", "Configuracion de ApiConfig, AuthInterceptor, SecureStorage, dioProvider", "03/09/2026", "04/09/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 0", "Routing con go_router", "Configuracion de AppRouter con ShellRoute, rutas autenticadas y publicas", "05/09/2026", "05/09/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 0", "Modelos de dominio", "User, Product, Category, Order, CartItem, BlogPost, Service", "06/09/2026", "07/09/2026", 2, "Norberto Suaste", "Completado"),

    # FASE 1 - Autenticacion (Sep 8 - Sep 14)
    @("Fase 1", "Login y registro", "LoginPage, RegisterPage, AuthController, AuthRepository", "08/09/2026", "10/09/2026", 3, "Norberto Suaste", "Completado"),
    @("Fase 1", "Verificacion de email y 2FA", "VerifyAccountPage, ForgotPasswordPage, ResetPasswordPage", "11/09/2026", "12/09/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 1", "Refresh de tokens automatico", "Metodo refresh en AuthRepository, interceptor single-flight, restauracion de sesion con refresh", "13/09/2026", "14/09/2026", 2, "Norberto Suaste", "Completado"),

    # FASE 2 - Home y navegacion (Sep 15 - Sep 20)
    @("Fase 2", "HomePage con SliverAppBar", "Hero con gradiente, carrusel de destacados, grid de categorias, CTA contacto", "15/09/2026", "17/09/2026", 3, "Norberto Suaste", "Completado"),
    @("Fase 2", "MainShell con bottom navigation", "NavigationBar de 4 destinos, FAB del chatbot, IndexedStack implicito", "18/09/2026", "19/09/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 2", "SplashScreen", "Pantalla de inicio con logo VITO, restauracion de sesion, redireccion", "20/09/2026", "20/09/2026", 1, "Norberto Suaste", "Completado"),

    # FASE 3 - Catalogo y tienda (Sep 21 - Sep 28)
    @("Fase 3", "ProductsPage y ProductCard", "Grid de productos con CachedNetworkImage, badge de descuento, favorito toggle", "21/09/2026", "23/09/2026", 3, "Norberto Suaste", "Completado"),
    @("Fase 3", "ProductDetailPage", "Detalle con galeria, descripcion, precio, agregar al carrito", "24/09/2026", "25/09/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 3", "StorePage con filtros", "Busqueda, filtros por categoria, ordenamiento, grid de productos", "26/09/2026", "27/09/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 3", "FavoritesPage (memoria)", "Grid de favoritos con StateView, toggle desde ProductCard", "28/09/2026", "28/09/2026", 1, "Norberto Suaste", "Completado"),

    # FASE 4 - Carrito, checkout y favoritos (Sep 29 - Oct 7)
    @("Fase 4", "CartPage y CartController", "Lista de items, cantidad, subtotal, total, vaciar carrito, checkout CTA", "29/09/2026", "30/09/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 4", "CheckoutRepository - Stripe", "createOrder, getStripePaymentIntent, PaymentSheet de flutter_stripe", "01/10/2026", "02/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 4", "Checkout - MercadoPago y SPEI", "getMercadoPagoPreference, getSpeiPaymentData, dialog SPEI, launchUrl MercadoPago", "03/10/2026", "04/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 4", "Checkout - Opciones de envio", "getShippingOptions, getAvailablePaymentMethods, RadioListTile de envio, resumen con costo", "05/10/2026", "05/10/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 4", "Favoritos con backend", "FavoritesRepository (CRUD /api/wishlist), sincronizacion en FavoritesController", "06/10/2026", "07/10/2026", 2, "Norberto Suaste", "Completado"),

    # FASE 5 - Cuenta (Oct 8 - Oct 16)
    @("Fase 5", "AccountRepository - Orders", "getOrders, getProfile, updateProfile", "08/10/2026", "09/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 5", "AccountRepository - Quotes/Invoices/Services", "getQuotes, getInvoices, getUserServices, changePassword", "10/10/2026", "11/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 5", "AccountPage - Tab de Ordenes", "OrdersTab con FutureBuilder, OrderCard, StatusBadge, RefreshIndicator", "12/10/2026", "13/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 5", "AccountPage - Quotes/Services/Invoices", "Tabs con datos reales del backend, cards con estado, loading/error/empty", "14/10/2026", "14/10/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 5", "AccountPage - Edicion de perfil", "Dialogo con firstName/lastName/phone, updateUser en AuthController", "15/10/2026", "15/10/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 5", "AccountPage - Cambio de contrasena", "Dialogo con currentPassword/newPassword/confirmPassword, validacion", "16/10/2026", "16/10/2026", 1, "Norberto Suaste", "Completado"),

    # FASE 6 - Blog y contacto (Oct 17 - Oct 22)
    @("Fase 6", "BlogPage y BlogCard", "Lista de posts con StateView, filtros por categoria, BlogPostPage con HTML", "17/10/2026", "18/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 6", "ContactPage - Formulario", "Formulario con validacion, ContactRepository, envio de mensaje al backend", "19/10/2026", "20/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 6", "ContactPage - Mapa y datos", "Datos externalizados a _ContactData, mapa interactivo con CustomPaint, launchUrl Google Maps", "21/10/2026", "22/10/2026", 2, "Norberto Suaste", "Completado"),

    # FASE 7 - Chatbot (Oct 23 - Oct 25)
    @("Fase 7", "ChatbotSheet con Socket.IO", "Chatbot en tiempo real via socket_io_client, ChatbotRepository, sheet modal", "23/10/2026", "25/10/2026", 3, "Norberto Suaste", "Completado"),

    # FASE 8 - i18n, accesibilidad y tests (Oct 26 - Nov 2)
    @("Fase 8", "Sistema i18n (es/en)", "AppStrings con diccionarios es/en, extension tr() en WidgetRef", "26/10/2026", "27/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 8", "Migracion de strings a i18n", "HomePage, StorePage, FavoritesPage, CartPage, ServicesPage, BlogPage", "28/10/2026", "29/10/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 8", "Accesibilidad", "Widget Accessibility.dart, Semantic labels en MainShell y ProductCard, touch targets 48dp", "30/10/2026", "30/10/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 8", "Tests unitarios", "Order, Product, User, AppStrings, CheckoutModels (68 tests, todos pasan)", "31/10/2026", "01/11/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 8", "Tests de widgets", "StateView (loading/empty/error/data), 7 escenarios", "02/11/2026", "02/11/2026", 1, "Norberto Suaste", "Completado"),

    # FASE 9 - Release (Nov 3 - Nov 9)
    @("Fase 9", "Limpieza debug UI", "Eliminacion de _debugInfoNotifier y debugPrint en ProductCard y HomePage", "03/11/2026", "03/11/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 9", "Migracion lucide_icons", "Cambio a lucide_icons_flutter 3.1.17 por compatibilidad con Flutter 3.47", "04/11/2026", "04/11/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 9", "Splash screen nativo", "SplashScreen con logo VITO, colores de marca, indicador de carga", "05/11/2026", "05/11/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 9", "Configuracion de iconos", "flutter_launcher_icons.yaml, SVG del logo, assets/icon/", "06/11/2026", "06/11/2026", 1, "Norberto Suaste", "Completado"),
    @("Fase 9", "Manual de despliegue", "docs/MANUAL_DESPLIEGUE.md con APK/IPA, firmado, App Store, Play Store", "07/11/2026", "08/11/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 9", "Actualizacion del README", "Marcado de todas las fases como completadas, referencia al manual", "09/11/2026", "09/11/2026", 1, "Norberto Suaste", "Completado"),

    # FASE 10 - Documentacion del proyecto (Nov 10 - Nov 14)
    @("Fase 10", "Analisis empresarial VITO", "Antecedentes, productos, organigrama, clientes, competidores, sustitutos, SWOT", "10/11/2026", "11/11/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 10", "Presentacion ejecutiva", "Oportunidades, medios digitales, propuesta iOS, impacto en satisfaccion", "12/11/2026", "13/11/2026", 2, "Norberto Suaste", "Completado"),
    @("Fase 10", "Minuta de acuerdo (HTML+PDF)", "Minuta con un alumno, plan de trabajo, firmas, exportacion a PDF via Edge", "14/11/2026", "14/11/2026", 1, "Norberto Suaste", "Completado"),

    # PENDIENTE / FUTURO (Nov 15 en adelante)
    @("Futuro", "Configuracion de firmado Android", "Keystore, key.properties, build.gradle signingConfigs", "15/11/2026", "16/11/2026", 2, "Norberto Suaste", "Pendiente"),
    @("Futuro", "Publicacion Google Play Store", "AAB release, ficha de Play Store, politica de privacidad, revision", "17/11/2026", "20/11/2026", 4, "Norberto Suaste", "Pendiente"),
    @("Futuro", "Publicacion Apple App Store", "IPA release, App Store Connect, ficha, revision", "21/11/2026", "24/11/2026", 4, "Norberto Suaste", "Pendiente"),
    @("Futuro", "Notificaciones push", "Configuracion FCM/APNs, integracion con backend", "25/11/2026", "27/11/2026", 3, "Norberto Suaste", "Pendiente"),
    @("Futuro", "Pruebas en dispositivo fisico", "Testing en Android e iOS reales, flujos completos", "28/11/2026", "30/11/2026", 3, "Norberto Suaste", "Pendiente")
)

# Colores por fase
$phaseColors = @{}
$phaseColors["Fase 0"] = 15128749
$phaseColors["Fase 1"] = 10079487
$phaseColors["Fase 2"] = 13434828
$phaseColors["Fase 3"] = 10053171
$phaseColors["Fase 4"] = 26367
$phaseColors["Fase 5"] = 13408767
$phaseColors["Fase 6"] = 52479
$phaseColors["Fase 7"] = 16750848
$phaseColors["Fase 8"] = 9671571
$phaseColors["Fase 9"] = 49344
$phaseColors["Fase 10"] = 16711680
$phaseColors["Futuro"] = 8421504

$estadoColors = @{}
$estadoColors["Completado"] = 52428
$estadoColors["Pendiente"] = 26367
$estadoColors["En progreso"] = 26367

# Formatear columnas de fecha como texto antes de escribir
$sheet.Range("D5:E$($data.Count + 4)").NumberFormat = "@"

# Escribir datos
$row = 5
foreach ($item in $data) {
    for ($col = 0; $col -lt $item.Count; $col++) {
        $cell = $sheet.Cells.Item($row, $col + 1)
        $cell.Value2 = [string]$item[$col]
        $cell.Borders.LineStyle = 1
        $cell.Borders.Color = 11119017
        $cell.Font.Size = 10
        $cell.VerticalAlignment = -4108

        if ($col -eq 0) {
            $phaseName = $item[0]
            if ($phaseColors.ContainsKey($phaseName)) {
                $cell.Interior.Color = $phaseColors[$phaseName]
                $cell.Font.Bold = $true
                $cell.Font.Color = 16777215
            }
            $cell.HorizontalAlignment = -4108
        }

        if ($col -eq 7) {
            $estado = $item[7]
            if ($estadoColors.ContainsKey($estado)) {
                $cell.Interior.Color = $estadoColors[$estado]
                $cell.Font.Bold = $true
                $cell.Font.Color = 16777215
            }
            $cell.HorizontalAlignment = -4108
        }

        if ($col -eq 3 -or $col -eq 4 -or $col -eq 5 -or $col -eq 6) {
            $cell.HorizontalAlignment = -4108
        }
    }
    $row++
}

# ============================================================
# RESUMEN
# ============================================================
$summaryRow = $row + 2

$sheet.Range("A$summaryRow`:D$summaryRow").Merge()
$sheet.Cells.Item($summaryRow, 1).Value2 = "RESUMEN DEL PROYECTO"
$sheet.Cells.Item($summaryRow, 1).Font.Bold = $true
$sheet.Cells.Item($summaryRow, 1).Font.Size = 14
$sheet.Cells.Item($summaryRow, 1).Font.Color = 16777215
$sheet.Cells.Item($summaryRow, 1).Interior.Color = 6710932
$sheet.Cells.Item($summaryRow, 1).HorizontalAlignment = -4108
$sheet.Rows.Item($summaryRow).RowHeight = 28

$summaryData = @(
    @("Total de tareas", ($data.Count)),
    @("Tareas completadas", (($data | Where-Object { $_[7] -eq "Completado" }).Count)),
    @("Tareas pendientes", (($data | Where-Object { $_[7] -eq "Pendiente" }).Count)),
    @("Total de fases", 11),
    @("Fases completadas", 11),
    @("Fecha de inicio del proyecto", "01/09/2026"),
    @("Fecha de finalizacion (desarrollo)", "14/11/2026"),
    @("Fecha limite (futuro/release)", "30/11/2026"),
    @("Duracion total de desarrollo (dias)", 75),
    @("Tests automatizados", 68),
    @("Flutter SDK", "3.47.2 (stable)"),
    @("Dart SDK", "3.13.2"),
    @("Estado del proyecto", "Completado - Listo para release")
)

$sr = $summaryRow + 2
foreach ($s in $summaryData) {
    $sheet.Cells.Item($sr, 1).Value2 = [string]$s[0]
    $sheet.Cells.Item($sr, 1).Font.Bold = $true
    $sheet.Cells.Item($sr, 1).Font.Size = 11
    $sheet.Cells.Item($sr, 1).Borders.LineStyle = 1
    $sheet.Cells.Item($sr, 1).Borders.Color = 11119017
    $sheet.Cells.Item($sr, 1).Interior.Color = 15132390

    $sheet.Range("B$sr`:D$sr").Merge()
    $sheet.Cells.Item($sr, 2).Value2 = [string]$s[1]
    $sheet.Cells.Item($sr, 2).Font.Size = 11
    $sheet.Cells.Item($sr, 2).Borders.LineStyle = 1
    $sheet.Cells.Item($sr, 2).Borders.Color = 11119017
    $sr++
}

# ============================================================
# ANCHOS DE COLUMNAS
# ============================================================
$sheet.Columns.Item(1).ColumnWidth = 12
$sheet.Columns.Item(2).ColumnWidth = 38
$sheet.Columns.Item(3).ColumnWidth = 65
$sheet.Columns.Item(4).ColumnWidth = 14
$sheet.Columns.Item(5).ColumnWidth = 14
$sheet.Columns.Item(6).ColumnWidth = 10
$sheet.Columns.Item(7).ColumnWidth = 18
$sheet.Columns.Item(8).ColumnWidth = 14

# Congelar paneles
$sheet.Cells.Item(5, 1).Select()
$excel.ActiveWindow.FreezePanes = $true

# Autofiltro
$sheet.Range("A4:H$($row - 1)").AutoFilter() | Out-Null

# ============================================================
# HOJA 2 - GANTT
# ============================================================
$sheet2 = $workbook.Worksheets.Add([System.Reflection.Missing]::Value, $sheet)
$sheet2.Name = "Gantt"

$sheet2.Range("A1:AR1").Merge()
$sheet2.Cells.Item(1, 1).Value2 = "DIAGRAMA DE GANTT - VitoStoreApp (Septiembre - Noviembre 2026)"
$sheet2.Cells.Item(1, 1).Font.Size = 14
$sheet2.Cells.Item(1, 1).Font.Bold = $true
$sheet2.Cells.Item(1, 1).Font.Color = 16777215
$sheet2.Cells.Item(1, 1).Interior.Color = 6710932
$sheet2.Cells.Item(1, 1).HorizontalAlignment = -4108
$sheet2.Rows.Item(1).RowHeight = 30

# Encabezados
$sheet2.Cells.Item(3, 1).Value2 = "Fase"
$sheet2.Cells.Item(3, 2).Value2 = "Tarea"
$sheet2.Cells.Item(3, 1).Font.Bold = $true
$sheet2.Cells.Item(3, 2).Font.Bold = $true
$sheet2.Cells.Item(3, 1).Interior.Color = 6710932
$sheet2.Cells.Item(3, 2).Interior.Color = 6710932
$sheet2.Cells.Item(3, 1).Font.Color = 16777215
$sheet2.Cells.Item(3, 2).Font.Color = 16777215
$sheet2.Cells.Item(3, 1).HorizontalAlignment = -4108
$sheet2.Cells.Item(3, 2).HorizontalAlignment = -4108

# Dias: del 1 de septiembre al 30 de noviembre (91 dias)
$startDate = [datetime]"2026-09-01"
$totalDays = 91
for ($d = 0; $d -lt $totalDays; $d++) {
    $currentDate = $startDate.AddDays($d)
    $col = $d + 3
    $cell = $sheet2.Cells.Item(3, $col)
    $cell.Value2 = $currentDate.ToString("dd/MM")
    $cell.Font.Size = 7
    $cell.Font.Bold = $true
    $cell.HorizontalAlignment = -4108
    $cell.Interior.Color = 6710932
    $cell.Font.Color = 16777215
    $cell.Borders.LineStyle = 1
    $cell.Borders.Color = 11119017
    $cell.ColumnWidth = 4.5

    # Marcar cambio de mes con linea mas gruesa
    if ($currentDate.Day -eq 1 -and $d -gt 0) {
        $cell.Borders.Color = 0
        $cell.Borders.Weight = -4138  # xlThick
    }

    # Fines de semana en gris
    $dayOfWeek = [int]$currentDate.DayOfWeek
    if ($dayOfWeek -eq 0 -or $dayOfWeek -eq 6) {
        for ($r = 4; $r -le ($data.Count + 3); $r++) {
            $sheet2.Cells.Item($r, $col).Interior.Color = 15132390
        }
    }
}

# Escribir tareas en Gantt
$ganttRow = 4
foreach ($item in $data) {
    $phaseName = $item[0]
    $taskName = $item[1]
    $fechaInicio = $item[3]
    $fechaFin = $item[4]
    $duracion = [int]$item[5]
    $estado = $item[7]

    $sheet2.Cells.Item($ganttRow, 1).Value2 = [string]$phaseName
    $sheet2.Cells.Item($ganttRow, 2).Value2 = [string]$taskName
    $sheet2.Cells.Item($ganttRow, 1).Font.Size = 9
    $sheet2.Cells.Item($ganttRow, 2).Font.Size = 9
    $sheet2.Cells.Item($ganttRow, 1).Borders.LineStyle = 1
    $sheet2.Cells.Item($ganttRow, 2).Borders.LineStyle = 1
    $sheet2.Cells.Item($ganttRow, 1).Borders.Color = 11119017
    $sheet2.Cells.Item($ganttRow, 2).Borders.Color = 11119017

    if ($phaseColors.ContainsKey($phaseName)) {
        $sheet2.Cells.Item($ganttRow, 1).Interior.Color = $phaseColors[$phaseName]
        $sheet2.Cells.Item($ganttRow, 1).Font.Color = 16777215
        $sheet2.Cells.Item($ganttRow, 1).Font.Bold = $true
    }

    # Barra de Gantt
    if ($fechaInicio -ne "Pendiente" -and $duracion -gt 0) {
        $start = [datetime]::ParseExact($fechaInicio, "dd/MM/yyyy", $null)
        $dayOffset = [int]($start - $startDate).TotalDays

        $barColor = 52428
        if ($estado -eq "Pendiente") { $barColor = 26367 }
        if ($estado -eq "En progreso") { $barColor = 26367 }

        for ($d = 0; $d -lt $duracion; $d++) {
            $col = $dayOffset + $d + 3
            if ($col -ge 3 -and $col -lt ($totalDays + 3)) {
                $cell = $sheet2.Cells.Item($ganttRow, $col)
                $cell.Interior.Color = $barColor
                $cell.Borders.LineStyle = 1
                $cell.Borders.Color = $barColor
            }
        }
    }

    $ganttRow++
}

# Anchos de columnas Gantt
$sheet2.Columns.Item(1).ColumnWidth = 12
$sheet2.Columns.Item(2).ColumnWidth = 38

# Congelar paneles Gantt
$sheet2.Cells.Item(4, 3).Select()
$excel.ActiveWindow.FreezePanes = $true

# ============================================================
# GUARDAR
# ============================================================
$outputPath = "C:\Users\Norbe\Desktop\repositorios\VitoStoreApp\docs\Cronograma_VitoStoreApp.xlsx"
$workbook.SaveAs($outputPath, 51)
$workbook.Close()
$excel.Quit()

[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sheet) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sheet2) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Output "Cronograma generado: $outputPath"
