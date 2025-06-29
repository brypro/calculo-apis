#!/usr/bin/env python3
"""
Análisis Matemático de Latencias T(x), T'(x), T''(x)
Procesa datos de benchmark para modelado polinómico y análisis de derivadas
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from scipy.optimize import curve_fit
import sys
import os
from datetime import datetime

# Configuración de matplotlib para mejor visualización
try:
    plt.style.use('seaborn-v0_8')
except:
    plt.style.use('seaborn')
sns.set_palette("husl")

def load_benchmark_data(csv_path):
    """Carga y procesa datos del benchmark"""
    print(f"📊 Cargando datos desde: {csv_path}")
    
    try:
        df = pd.read_csv(csv_path)
        print(f"✅ Datos cargados: {len(df)} registros")
        return df
    except Exception as e:
        print(f"❌ Error cargando datos: {e}")
        return None

def polynomial_fit(x, y, degree=2):
    """Ajuste polinómico usando numpy.polyfit"""
    coeffs = np.polyfit(x, y, degree)
    poly_func = np.poly1d(coeffs)
    
    # Calcular R²
    y_pred = poly_func(x)
    ss_res = np.sum((y - y_pred) ** 2)
    ss_tot = np.sum((y - np.mean(y)) ** 2)
    r_squared = 1 - (ss_res / ss_tot)
    
    return coeffs, poly_func, r_squared

def calculate_derivatives(coeffs):
    """Calcula T'(x) y T''(x) desde los coeficientes polinómicos"""
    # Para T(x) = ax² + bx + c
    # T'(x) = 2ax + b
    # T''(x) = 2a
    
    if len(coeffs) >= 3:  # Grado 2
        a, b, c = coeffs[0], coeffs[1], coeffs[2]
        
        # Primera derivada: T'(x) = 2ax + b
        first_deriv_coeffs = [2*a, b]
        
        # Segunda derivada: T''(x) = 2a
        second_deriv = 2*a
        
        return first_deriv_coeffs, second_deriv, a, b, c
    else:
        return None, None, None, None, None

def find_critical_points(first_deriv_coeffs, threshold=10.0):
    """Encuentra puntos críticos donde T'(x) cruza un umbral"""
    if len(first_deriv_coeffs) >= 2:
        # T'(x) = 2ax + b = threshold
        # x = (threshold - b) / (2a)
        a_prime, b_prime = first_deriv_coeffs[0], first_deriv_coeffs[1]
        
        if a_prime != 0:
            x_critical = (threshold - b_prime) / a_prime
            return x_critical
    return None

def analyze_api_performance(df, api_name):
    """Análisis completo de una API específica"""
    print(f"\n🔬 ANÁLISIS MATEMÁTICO: {api_name}")
    print("=" * 50)
    
    api_data = df[df['API'] == api_name].copy()
    
    if len(api_data) == 0:
        print(f"❌ No hay datos para {api_name}")
        return None
    
    # Agrupar por concurrencia y calcular promedios
    grouped = api_data.groupby('Concurrency').agg({
        'LatencyP95': ['mean', 'std'],
        'RequestsPerSec': ['mean', 'std'],
        'ErrorRate': 'mean'
    }).reset_index()
    
    # Aplanar columnas
    grouped.columns = ['Concurrency', 'LatencyP95_mean', 'LatencyP95_std', 
                      'RPS_mean', 'RPS_std', 'ErrorRate_mean']
    
    x = grouped['Concurrency'].values
    y = grouped['LatencyP95_mean'].values
    
    print(f"📈 Puntos de datos: {len(x)}")
    print(f"📊 Rango concurrencia: {x.min()} - {x.max()}")
    print(f"🕐 Rango latencia P95: {y.min():.2f} - {y.max():.2f} ms")
    
    # Ajuste polinómico T(x) = ax² + bx + c
    coeffs, poly_func, r_squared = polynomial_fit(x, y, degree=2)
    
    print(f"\n📐 MODELADO POLINÓMICO T(x) = ax² + bx + c")
    print(f"   a = {coeffs[0]:.6f}")
    print(f"   b = {coeffs[1]:.6f}")
    print(f"   c = {coeffs[2]:.6f}")
    print(f"   R² = {r_squared:.4f}")
    
    # Calcular derivadas
    first_deriv_coeffs, second_deriv, a, b, c = calculate_derivatives(coeffs)
    
    print(f"\n📊 ANÁLISIS DE DERIVADAS")
    print(f"   T'(x) = {first_deriv_coeffs[0]:.6f}x + {first_deriv_coeffs[1]:.6f}")
    print(f"   T''(x) = {second_deriv:.6f}")
    
    # Interpretación de la segunda derivada
    if second_deriv > 0:
        degradation_type = "ACELERADA (convexa)"
        resilience = "BAJA"
    elif second_deriv < 0:
        degradation_type = "DESACELERADA (cóncava)"
        resilience = "ALTA"
    else:
        degradation_type = "LINEAL"
        resilience = "MEDIA"
    
    print(f"   Degradación: {degradation_type}")
    print(f"   Resiliencia: {resilience}")
    
    # Encontrar punto crítico (umbral +10 ms/unidad)
    x_critical = find_critical_points(first_deriv_coeffs, threshold=10.0)
    if x_critical and x_critical > 0:
        print(f"   Punto crítico (T'(x)=10): x* = {x_critical:.1f}")
        latency_at_critical = poly_func(x_critical)
        print(f"   Latencia en x*: {latency_at_critical:.2f} ms")
    
    # Generar datos para gráfica
    x_smooth = np.linspace(x.min(), x.max(), 100)
    y_smooth = poly_func(x_smooth)
    y_deriv = np.polyval(first_deriv_coeffs, x_smooth)
    
    return {
        'api_name': api_name,
        'x_data': x,
        'y_data': y,
        'x_smooth': x_smooth,
        'y_smooth': y_smooth,
        'y_deriv': y_deriv,
        'coeffs': coeffs,
        'r_squared': r_squared,
        'first_deriv_coeffs': first_deriv_coeffs,
        'second_deriv': second_deriv,
        'x_critical': x_critical,
        'degradation_type': degradation_type,
        'resilience': resilience,
        'grouped_data': grouped
    }

def create_mathematical_plots(results):
    """Crea gráficas T(x) y T'(x) para todas las APIs"""
    print(f"\n📊 GENERANDO GRÁFICAS MATEMÁTICAS")
    
    # Configurar subplots
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
    fig.suptitle('Análisis Matemático de Latencias: T(x), T\'(x)', fontsize=16, fontweight='bold')
    
    colors = ['#e74c3c', '#3498db', '#2ecc71', '#f39c12']
    
    # Gráfica 1: T(x) - Latencias vs Concurrencia
    for i, result in enumerate(results):
        if result:
            ax1.scatter(result['x_data'], result['y_data'], 
                       color=colors[i], alpha=0.7, s=50, 
                       label=f"{result['api_name']} (datos)")
            ax1.plot(result['x_smooth'], result['y_smooth'], 
                    color=colors[i], linewidth=2, linestyle='-',
                    label=f"{result['api_name']} T(x)")
    
    ax1.set_xlabel('Concurrencia (x)')
    ax1.set_ylabel('Latencia P95 (ms)')
    ax1.set_title('T(x): Latencia vs Concurrencia')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # Gráfica 2: T'(x) - Derivadas
    for i, result in enumerate(results):
        if result:
            ax2.plot(result['x_smooth'], result['y_deriv'], 
                    color=colors[i], linewidth=2, linestyle='--',
                    label=f"{result['api_name']} T'(x)")
    
    ax2.axhline(y=10, color='red', linestyle=':', alpha=0.7, label='Umbral crítico (10 ms/unidad)')
    ax2.set_xlabel('Concurrencia (x)')
    ax2.set_ylabel('Tasa de degradación T\'(x)')
    ax2.set_title('T\'(x): Tasa de Degradación')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    # Gráfica 3: Comparación de coeficientes 'a'
    api_names = [r['api_name'] for r in results if r]
    a_coeffs = [r['coeffs'][0] for r in results if r]
    
    bars = ax3.bar(api_names, a_coeffs, color=colors[:len(api_names)], alpha=0.7)
    ax3.set_ylabel('Coeficiente a (curvatura)')
    ax3.set_title('Comparación de Resiliencia (menor a = mejor)')
    ax3.grid(True, alpha=0.3, axis='y')
    
    # Añadir valores en las barras
    for bar, coeff in zip(bars, a_coeffs):
        height = bar.get_height()
        ax3.text(bar.get_x() + bar.get_width()/2., height,
                f'{coeff:.4f}', ha='center', va='bottom')
    
    # Gráfica 4: R² y calidad del ajuste
    r_squared_values = [r['r_squared'] for r in results if r]
    
    bars = ax4.bar(api_names, r_squared_values, color=colors[:len(api_names)], alpha=0.7)
    ax4.set_ylabel('R² (calidad del ajuste)')
    ax4.set_title('Calidad del Modelado Polinómico')
    ax4.set_ylim(0, 1)
    ax4.grid(True, alpha=0.3, axis='y')
    
    # Añadir valores en las barras
    for bar, r2 in zip(bars, r_squared_values):
        height = bar.get_height()
        ax4.text(bar.get_x() + bar.get_width()/2., height,
                f'{r2:.3f}', ha='center', va='bottom')
    
    plt.tight_layout()
    
    # Guardar gráfica
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    plot_filename = f"mathematical_analysis_{timestamp}.png"
    plt.savefig(plot_filename, dpi=300, bbox_inches='tight')
    print(f"📊 Gráfica guardada: {plot_filename}")
    
    # No mostrar la gráfica para evitar problemas en headless
    # plt.show()
    
    return plot_filename

def generate_markdown_report(results, csv_path, plot_filename):
    """Genera reporte en Markdown con análisis matemático completo"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    md_content = f"""# Análisis Matemático de Latencias: T(x), T'(x), T''(x)

**Fecha:** {timestamp}
**Datos fuente:** {csv_path}

## 1. Resumen Ejecutivo

Este análisis presenta el modelado matemático de las latencias de cuatro APIs (Go, Python, Node.js, .NET) 
utilizando ajustes polinómicos de grado 2 y análisis de derivadas para determinar la resiliencia 
y escalabilidad bajo carga.

## 2. Metodología

### 2.1 Modelo Matemático
- **Función de latencia:** T(x) = ax² + bx + c
- **Primera derivada:** T'(x) = 2ax + b (tasa de degradación)
- **Segunda derivada:** T''(x) = 2a (aceleración de la degradación)

### 2.2 Interpretación
- **a > 0:** Degradación acelerada (convexa) - Baja resiliencia
- **a < 0:** Degradación desacelerada (cóncava) - Alta resiliencia  
- **a ≈ 0:** Degradación lineal - Resiliencia media

## 3. Resultados por API

"""

    # Tabla comparativa
    md_content += "### 3.1 Tabla Comparativa\n\n"
    md_content += "| API | a (curvatura) | b (pendiente) | c (intercepto) | R² | Degradación | Resiliencia |\n"
    md_content += "|-----|---------------|---------------|----------------|----|-----------|-----------|\n"
    
    for result in results:
        if result:
            a, b, c = result['coeffs'][0], result['coeffs'][1], result['coeffs'][2]
            md_content += f"| {result['api_name']} | {a:.6f} | {b:.6f} | {c:.6f} | {result['r_squared']:.4f} | {result['degradation_type']} | {result['resilience']} |\n"
    
    # Análisis detallado por API
    md_content += "\n### 3.2 Análisis Detallado\n\n"
    
    for result in results:
        if result:
            md_content += f"#### {result['api_name']} API\n\n"
            md_content += f"**Ecuación:** T(x) = {result['coeffs'][0]:.6f}x² + {result['coeffs'][1]:.6f}x + {result['coeffs'][2]:.6f}\n\n"
            md_content += f"**Derivadas:**\n"
            md_content += f"- T'(x) = {result['first_deriv_coeffs'][0]:.6f}x + {result['first_deriv_coeffs'][1]:.6f}\n"
            md_content += f"- T''(x) = {result['second_deriv']:.6f}\n\n"
            
            if result['x_critical'] and result['x_critical'] > 0:
                md_content += f"**Punto crítico:** x* = {result['x_critical']:.1f} (donde T'(x) = 10 ms/unidad)\n\n"
            
            md_content += f"**Interpretación:** {result['degradation_type'].lower()}, resiliencia {result['resilience'].lower()}\n\n"
    
    # Ranking de resiliencia
    md_content += "## 4. Ranking de Resiliencia\n\n"
    md_content += "Ordenado por coeficiente 'a' (menor = mejor resiliencia):\n\n"
    
    # Ordenar por coeficiente a
    sorted_results = sorted([r for r in results if r], key=lambda x: x['coeffs'][0])
    
    for i, result in enumerate(sorted_results, 1):
        emoji = "🥇" if i == 1 else "🥈" if i == 2 else "🥉" if i == 3 else "🏅"
        md_content += f"{emoji} **{i}. {result['api_name']}** - a = {result['coeffs'][0]:.6f} ({result['resilience']})\n\n"
    
    # Conclusiones
    md_content += "## 5. Conclusiones\n\n"
    
    best_api = sorted_results[0]
    worst_api = sorted_results[-1]
    
    md_content += f"### 5.1 Mejor Resiliencia: {best_api['api_name']}\n"
    md_content += f"- Coeficiente a = {best_api['coeffs'][0]:.6f}\n"
    md_content += f"- Degradación: {best_api['degradation_type'].lower()}\n"
    md_content += f"- Mantiene mejor rendimiento bajo alta concurrencia\n\n"
    
    md_content += f"### 5.2 Menor Resiliencia: {worst_api['api_name']}\n"
    md_content += f"- Coeficiente a = {worst_api['coeffs'][0]:.6f}\n"
    md_content += f"- Degradación: {worst_api['degradation_type'].lower()}\n"
    md_content += f"- Rendimiento se degrada más rápidamente\n\n"
    
    md_content += "### 5.3 Recomendaciones\n\n"
    md_content += "1. **Escalabilidad horizontal:** Considerar réplicas para APIs con a > 0.001\n"
    md_content += "2. **Monitoreo:** Implementar alertas cuando T'(x) > 10 ms/unidad\n"
    md_content += "3. **Optimización:** Priorizar APIs con mayor coeficiente 'a'\n\n"
    
    md_content += f"## 6. Anexos\n\n"
    md_content += f"### 6.1 Gráficas\n\n"
    md_content += f"![Análisis Matemático]({plot_filename})\n\n"
    md_content += f"### 6.2 Datos Fuente\n\n"
    md_content += f"Archivo CSV: `{csv_path}`\n\n"
    
    # Guardar reporte
    report_filename = f"mathematical_analysis_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
    with open(report_filename, 'w', encoding='utf-8') as f:
        f.write(md_content)
    
    print(f"📄 Reporte generado: {report_filename}")
    return report_filename

def main():
    """Función principal"""
    print("🔬 ANÁLISIS MATEMÁTICO DE LATENCIAS T(x), T'(x), T''(x)")
    print("=" * 60)
    
    # Buscar archivo CSV más reciente
    csv_files = [f for f in os.listdir('.') if f.startswith('mathematical-benchmark-') and f.endswith('.csv')]
    
    if not csv_files:
        print("❌ No se encontraron archivos CSV de benchmark")
        print("💡 Ejecuta primero: .\\scripts\\mathematical-benchmark.ps1")
        return
    
    # Usar el archivo más reciente
    csv_path = max(csv_files, key=os.path.getctime)
    print(f"📊 Usando archivo: {csv_path}")
    
    # Cargar datos
    df = load_benchmark_data(csv_path)
    if df is None:
        return
    
    # Analizar cada API
    apis = ['Go', 'Python', 'NodeJS', 'DotNet']
    results = []
    
    for api in apis:
        result = analyze_api_performance(df, api)
        results.append(result)
    
    # Crear gráficas
    plot_filename = create_mathematical_plots(results)
    
    # Generar reporte
    report_filename = generate_markdown_report(results, csv_path, plot_filename)
    
    print(f"\n✅ ANÁLISIS COMPLETADO")
    print(f"📊 Gráficas: {plot_filename}")
    print(f"📄 Reporte: {report_filename}")

if __name__ == "__main__":
    main() 