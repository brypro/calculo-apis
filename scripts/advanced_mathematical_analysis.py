#!/usr/bin/env python3
"""
Análisis Matemático Avanzado de Latencias
Calcula T(x), T'(x), T''(x) y compara modelos para diferentes APIs
"""

import pandas as pd
import numpy as np
from scipy import stats
from scipy.optimize import curve_fit
import matplotlib.pyplot as plt
import seaborn as sns
import json
import os
import glob
from typing import Dict, List, Tuple
import warnings
warnings.filterwarnings('ignore')

# Configurar estilo
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

class AdvancedLatencyAnalyzer:
    def __init__(self, data_dir: str = "data"):
        self.data_dir = data_dir
        self.results = {}
        
    def load_all_api_data(self) -> Dict[str, pd.DataFrame]:
        """Carga datos de todas las APIs disponibles"""
        print("📊 Cargando datos de todas las APIs...")
        
        api_data = {}
        
        # Buscar archivos CSV de diferentes APIs
        csv_files = glob.glob(os.path.join(self.data_dir, "*_latency_data.csv"))
        
        if not csv_files:
            # Si no hay archivos específicos, buscar el general
            general_csv = os.path.join(self.data_dir, "latency_data.csv")
            if os.path.exists(general_csv):
                df = pd.read_csv(general_csv)
                api_data["general"] = df
                print(f"✅ Cargado: latency_data.csv ({len(df)} puntos)")
        
        for csv_file in csv_files:
            api_name = os.path.basename(csv_file).replace("_latency_data.csv", "")
            df = pd.read_csv(csv_file)
            api_data[api_name] = df
            print(f"✅ Cargado: {api_name} ({len(df)} puntos)")
        
        return api_data
    
    def fit_polynomial_model(self, x: np.ndarray, y: np.ndarray, degree: int = 2) -> Tuple[np.ndarray, float]:
        """Ajusta un modelo polinomial y calcula R²"""
        coeffs = np.polyfit(x, y, degree)
        y_pred = np.polyval(coeffs, x)
        r_squared = 1 - np.sum((y - y_pred) ** 2) / np.sum((y - np.mean(y)) ** 2)
        return coeffs, r_squared
    
    def fit_exponential_model(self, x: np.ndarray, y: np.ndarray) -> Tuple[Tuple[float, float], float]:
        """Ajusta un modelo exponencial y = a * exp(b*x)"""
        def exponential_func(x, a, b):
            return a * np.exp(b * x)
        
        try:
            popt, pcov = curve_fit(exponential_func, x, y, p0=[1, 0.01])
            y_pred = exponential_func(x, *popt)
            r_squared = 1 - np.sum((y - y_pred) ** 2) / np.sum((y - np.mean(y)) ** 2)
            return popt, r_squared
        except:
            return (0, 0), 0
    
    def fit_logarithmic_model(self, x: np.ndarray, y: np.ndarray) -> Tuple[Tuple[float, float], float]:
        """Ajusta un modelo logarítmico y = a * ln(x) + b"""
        def logarithmic_func(x, a, b):
            return a * np.log(x) + b
        
        try:
            popt, pcov = curve_fit(logarithmic_func, x, y, p0=[1, 0])
            y_pred = logarithmic_func(x, *popt)
            r_squared = 1 - np.sum((y - y_pred) ** 2) / np.sum((y - np.mean(y)) ** 2)
            return popt, r_squared
        except:
            return (0, 0), 0
    
    def calculate_derivatives(self, coeffs: np.ndarray, x_values: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """Calcula primera y segunda derivadas para modelo polinomial"""
        # Para T(x) = ax² + bx + c
        a, b, c = coeffs
        
        # T'(x) = 2ax + b
        deriv1 = 2 * a * x_values + b
        
        # T''(x) = 2a
        deriv2 = np.full_like(x_values, 2 * a)
        
        return deriv1, deriv2
    
    def analyze_api_performance(self, api_name: str, df: pd.DataFrame) -> Dict:
        """Análisis completo de una API"""
        print(f"\n🔬 Analizando {api_name}...")
        
        x = df['concurrency'].values
        y_p95 = df['latency_p95_ms'].values
        y_mean = df['latency_mean_ms'].values
        throughput = df['requests_per_sec'].values
        
        # Ajustar diferentes modelos
        models = {}
        
        # Modelo polinomial de segundo grado
        poly_coeffs, poly_r2 = self.fit_polynomial_model(x, y_p95, 2)
        models['polynomial'] = {
            'coeffs': poly_coeffs,
            'r_squared': poly_r2,
            'equation': f"T(x) = {poly_coeffs[0]:.6f}x² + {poly_coeffs[1]:.6f}x + {poly_coeffs[2]:.6f}"
        }
        
        # Modelo exponencial
        exp_params, exp_r2 = self.fit_exponential_model(x, y_p95)
        models['exponential'] = {
            'params': exp_params,
            'r_squared': exp_r2,
            'equation': f"T(x) = {exp_params[0]:.6f} * exp({exp_params[1]:.6f}x)"
        }
        
        # Modelo logarítmico
        log_params, log_r2 = self.fit_logarithmic_model(x, y_p95)
        models['logarithmic'] = {
            'params': log_params,
            'r_squared': log_r2,
            'equation': f"T(x) = {log_params[0]:.6f} * ln(x) + {log_params[1]:.6f}"
        }
        
        # Encontrar el mejor modelo
        best_model = max(models.keys(), key=lambda k: models[k]['r_squared'])
        
        # Calcular derivadas para el modelo polinomial
        deriv1, deriv2 = self.calculate_derivatives(poly_coeffs, x)
        
        # Análisis de escalabilidad
        scalability_analysis = self.analyze_scalability(x, y_p95, throughput)
        
        return {
            'api_name': api_name,
            'data_points': len(df),
            'models': models,
            'best_model': best_model,
            'polynomial_derivatives': {
                'deriv1': deriv1.tolist(),
                'deriv2': deriv2.tolist(),
                'equation_deriv1': f"T'(x) = {2*poly_coeffs[0]:.6f}x + {poly_coeffs[1]:.6f}",
                'equation_deriv2': f"T''(x) = {2*poly_coeffs[0]:.6f}"
            },
            'scalability': scalability_analysis,
            'raw_data': {
                'concurrency': x.tolist(),
                'latency_p95': y_p95.tolist(),
                'latency_mean': y_mean.tolist(),
                'throughput': throughput.tolist()
            }
        }
    
    def analyze_scalability(self, x: np.ndarray, y_p95: np.ndarray, throughput: np.ndarray) -> Dict:
        """Analiza la escalabilidad de la API"""
        
        # Calcular tasas de crecimiento
        latency_growth_rate = np.gradient(y_p95, x)
        throughput_growth_rate = np.gradient(throughput, x)
        
        # Identificar punto de saturación (donde el throughput deja de crecer)
        saturation_point = None
        for i in range(1, len(throughput_growth_rate)):
            if throughput_growth_rate[i] < 0.1 * throughput_growth_rate[i-1]:
                saturation_point = x[i]
                break
        
        # Calcular eficiencia (throughput por unidad de latencia)
        efficiency = throughput / y_p95
        
        return {
            'latency_growth_rate': latency_growth_rate.tolist(),
            'throughput_growth_rate': throughput_growth_rate.tolist(),
            'efficiency': efficiency.tolist(),
            'saturation_point': saturation_point,
            'max_throughput': float(np.max(throughput)),
            'min_latency': float(np.min(y_p95)),
            'max_latency': float(np.max(y_p95))
        }
    
    def generate_comparative_analysis(self, api_results: Dict[str, Dict]) -> None:
        """Genera análisis comparativo entre APIs"""
        print("\n📊 Generando análisis comparativo...")
        
        # Crear figura con múltiples subplots
        fig, axes = plt.subplots(2, 3, figsize=(18, 12))
        fig.suptitle('Análisis Comparativo de APIs - Cálculo Diferencial de Latencias', 
                     fontsize=16, fontweight='bold')
        
        colors = sns.color_palette("husl", len(api_results))
        
        # 1. Latencia P95 vs Concurrencia
        ax1 = axes[0, 0]
        for i, (api_name, result) in enumerate(api_results.items()):
            x = result['raw_data']['concurrency']
            y = result['raw_data']['latency_p95']
            ax1.plot(x, y, marker='o', label=api_name, color=colors[i], linewidth=2)
        ax1.set_xlabel('Concurrencia')
        ax1.set_ylabel('Latencia P95 (ms)')
        ax1.set_title('T(x) - Latencia vs Concurrencia')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # 2. Primera derivada T'(x)
        ax2 = axes[0, 1]
        for i, (api_name, result) in enumerate(api_results.items()):
            x = result['raw_data']['concurrency']
            deriv1 = result['polynomial_derivatives']['deriv1']
            ax2.plot(x, deriv1, marker='s', label=f"{api_name} T'(x)", color=colors[i], linewidth=2)
        ax2.set_xlabel('Concurrencia')
        ax2.set_ylabel("T'(x) (ms/conc)")
        ax2.set_title("Primera Derivada - Cambio de Latencia")
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        # 3. Segunda derivada T''(x)
        ax3 = axes[0, 2]
        for i, (api_name, result) in enumerate(api_results.items()):
            x = result['raw_data']['concurrency']
            deriv2 = result['polynomial_derivatives']['deriv2']
            ax3.plot(x, deriv2, marker='^', label=f"{api_name} T''(x)", color=colors[i], linewidth=2)
        ax3.set_xlabel('Concurrencia')
        ax3.set_ylabel("T''(x) (ms/conc²)")
        ax3.set_title("Segunda Derivada - Aceleración")
        ax3.legend()
        ax3.grid(True, alpha=0.3)
        
        # 4. Throughput vs Concurrencia
        ax4 = axes[1, 0]
        for i, (api_name, result) in enumerate(api_results.items()):
            x = result['raw_data']['concurrency']
            throughput = result['raw_data']['throughput']
            ax4.plot(x, throughput, marker='D', label=api_name, color=colors[i], linewidth=2)
        ax4.set_xlabel('Concurrencia')
        ax4.set_ylabel('Throughput (req/s)')
        ax4.set_title('Throughput vs Concurrencia')
        ax4.legend()
        ax4.grid(True, alpha=0.3)
        
        # 5. Eficiencia
        ax5 = axes[1, 1]
        for i, (api_name, result) in enumerate(api_results.items()):
            x = result['raw_data']['concurrency']
            efficiency = result['scalability']['efficiency']
            ax5.plot(x, efficiency, marker='*', label=api_name, color=colors[i], linewidth=2)
        ax5.set_xlabel('Concurrencia')
        ax5.set_ylabel('Eficiencia (req/s/ms)')
        ax5.set_title('Eficiencia vs Concurrencia')
        ax5.legend()
        ax5.grid(True, alpha=0.3)
        
        # 6. Comparación de modelos (R²)
        ax6 = axes[1, 2]
        model_names = ['Polinomial', 'Exponencial', 'Logarítmico']
        api_names = list(api_results.keys())
        
        x_pos = np.arange(len(api_names))
        width = 0.25
        
        for i, model_type in enumerate(['polynomial', 'exponential', 'logarithmic']):
            r2_values = [api_results[api]['models'][model_type]['r_squared'] for api in api_names]
            ax6.bar(x_pos + i*width, r2_values, width, label=model_names[i], alpha=0.8)
        
        ax6.set_xlabel('API')
        ax6.set_ylabel('R²')
        ax6.set_title('Ajuste de Modelos (R²)')
        ax6.set_xticks(x_pos + width)
        ax6.set_xticklabels(api_names)
        ax6.legend()
        ax6.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(os.path.join(self.data_dir, 'advanced_comparative_analysis.png'), 
                   dpi=300, bbox_inches='tight')
        print(f"📈 Gráfico comparativo guardado: {self.data_dir}/advanced_comparative_analysis.png")
    
    def generate_mathematical_report(self, api_results: Dict[str, Dict]) -> None:
        """Genera reporte matemático detallado"""
        report_file = os.path.join(self.data_dir, 'mathematical_report.txt')
        
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("REPORTE MATEMÁTICO AVANZADO - ANÁLISIS DE LATENCIAS\n")
            f.write("=" * 60 + "\n\n")
            
            for api_name, result in api_results.items():
                f.write(f"🔬 ANÁLISIS DE {api_name.upper()}\n")
                f.write("-" * 40 + "\n")
                f.write(f"Puntos de datos: {result['data_points']}\n")
                f.write(f"Mejor modelo: {result['best_model']}\n\n")
                
                # Modelos
                f.write("📊 MODELOS MATEMÁTICOS:\n")
                for model_name, model_data in result['models'].items():
                    f.write(f"  {model_name.capitalize()}: {model_data['equation']}\n")
                    f.write(f"    R² = {model_data['r_squared']:.6f}\n")
                f.write("\n")
                
                # Derivadas
                f.write("🔬 DERIVADAS (Modelo Polinomial):\n")
                f.write(f"  T'(x) = {result['polynomial_derivatives']['equation_deriv1']}\n")
                f.write(f"  T''(x) = {result['polynomial_derivatives']['equation_deriv2']}\n\n")
                
                # Escalabilidad
                f.write("📈 ANÁLISIS DE ESCALABILIDAD:\n")
                f.write(f"  Throughput máximo: {result['scalability']['max_throughput']:.2f} req/s\n")
                f.write(f"  Latencia mínima: {result['scalability']['min_latency']:.2f} ms\n")
                f.write(f"  Latencia máxima: {result['scalability']['max_latency']:.2f} ms\n")
                if result['scalability']['saturation_point']:
                    f.write(f"  Punto de saturación: {result['scalability']['saturation_point']:.0f} conc\n")
                f.write("\n")
                
                f.write("=" * 60 + "\n\n")
            
            # Comparación entre APIs
            f.write("🏆 COMPARACIÓN ENTRE APIs:\n")
            f.write("=" * 40 + "\n\n")
            
            # Mejor throughput
            best_throughput = max(api_results.items(), 
                                key=lambda x: x[1]['scalability']['max_throughput'])
            f.write(f"🏅 Mejor throughput: {best_throughput[0]} ({best_throughput[1]['scalability']['max_throughput']:.2f} req/s)\n")
            
            # Menor latencia
            best_latency = min(api_results.items(), 
                             key=lambda x: x[1]['scalability']['min_latency'])
            f.write(f"⚡ Menor latencia: {best_latency[0]} ({best_latency[1]['scalability']['min_latency']:.2f} ms)\n")
            
            # Mejor escalabilidad (menor crecimiento de latencia)
            best_scalability = min(api_results.items(), 
                                 key=lambda x: np.mean(x[1]['scalability']['latency_growth_rate']))
            f.write(f"📈 Mejor escalabilidad: {best_scalability[0]} (crecimiento más lento)\n")
            
            # Mejor modelo matemático
            best_model_fit = max(api_results.items(), 
                               key=lambda x: x[1]['models'][x[1]['best_model']]['r_squared'])
            f.write(f"🎯 Mejor ajuste matemático: {best_model_fit[0]} (R² = {best_model_fit[1]['models'][best_model_fit[1]['best_model']]['r_squared']:.6f})\n")
        
        print(f"📄 Reporte matemático guardado: {report_file}")
    
    def run_analysis(self) -> None:
        """Ejecuta el análisis completo"""
        print("🚀 Iniciando análisis matemático avanzado")
        print("=" * 50)
        
        # Cargar datos
        api_data = self.load_all_api_data()
        
        if not api_data:
            print("❌ No se encontraron datos para analizar")
            return
        
        # Analizar cada API
        api_results = {}
        for api_name, df in api_data.items():
            result = self.analyze_api_performance(api_name, df)
            api_results[api_name] = result
        
        # Generar análisis comparativo
        if len(api_results) > 1:
            self.generate_comparative_analysis(api_results)
        
        # Generar reporte
        self.generate_mathematical_report(api_results)
        
        # Guardar resultados en JSON
        results_file = os.path.join(self.data_dir, 'advanced_analysis_results.json')
        with open(results_file, 'w') as f:
            json.dump(api_results, f, indent=2)
        
        print(f"\n🎉 Análisis completado!")
        print(f"📁 Resultados guardados en: {self.data_dir}")
        print(f"  - advanced_comparative_analysis.png")
        print(f"  - mathematical_report.txt")
        print(f"  - advanced_analysis_results.json")

if __name__ == "__main__":
    analyzer = AdvancedLatencyAnalyzer()
    analyzer.run_analysis() 