#!/usr/bin/env python3
"""
Script para analizar los resultados de benchmarks de APIs
Genera gráficos y estadísticas comparativas
"""

import json
import os
import glob
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from typing import Dict, List, Tuple
import numpy as np

# Configurar estilo de gráficos
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

class BenchmarkAnalyzer:
    def __init__(self, results_dir: str = "results"):
        self.results_dir = results_dir
        self.data = {}
        self.df = None
        
    def load_results(self) -> None:
        """Carga todos los archivos de resultados JSON"""
        print("📊 Cargando resultados de benchmarks...")
        
        # Buscar todos los archivos JSON en el directorio de resultados
        json_files = glob.glob(os.path.join(self.results_dir, "*.json"))
        
        if not json_files:
            print("❌ No se encontraron archivos de resultados")
            return
            
        for file_path in json_files:
            try:
                with open(file_path, 'r') as f:
                    result = json.load(f)
                    
                # Extraer información del nombre del archivo
                filename = os.path.basename(file_path)
                parts = filename.replace('.json', '').split('_')
                api_name = parts[0]
                concurrency = int(parts[1].replace('c', ''))
                
                # Agregar información adicional
                result['api_name'] = api_name
                result['concurrency'] = concurrency
                result['filename'] = filename
                
                if api_name not in self.data:
                    self.data[api_name] = []
                self.data[api_name].append(result)
                
                print(f"✅ Cargado: {filename}")
                
            except Exception as e:
                print(f"❌ Error cargando {file_path}: {e}")
    
    def create_dataframe(self) -> None:
        """Crea un DataFrame con todos los datos"""
        if not self.data:
            print("❌ No hay datos para procesar")
            return
            
        rows = []
        for api_name, results in self.data.items():
            for result in results:
                row = {
                    'api_name': api_name,
                    'concurrency': result['concurrency'],
                    'requests_per_sec': result['result']['requests_per_sec'],
                    'latency_mean_ms': result['result']['latency_mean_ms'],
                    'latency_p95_ms': result['result']['latency_p95_ms'],
                    'latency_p99_ms': result['result']['latency_p99_ms'],
                    'total_requests': result['result']['total_requests'],
                    'total_duration_sec': result['result']['total_duration_sec']
                }
                rows.append(row)
        
        self.df = pd.DataFrame(rows)
        print(f"📈 DataFrame creado con {len(self.df)} registros")
    
    def generate_plots(self) -> None:
        """Genera gráficos comparativos"""
        if self.df is None or self.df.empty:
            print("❌ No hay datos para graficar")
            return
            
        print("📊 Generando gráficos...")
        
        # Crear figura con subplots
        fig, axes = plt.subplots(2, 2, figsize=(15, 12))
        fig.suptitle('Benchmark Comparativo de APIs', fontsize=16, fontweight='bold')
        
        # 1. Throughput (requests/sec) vs Concurrencia
        ax1 = axes[0, 0]
        for api_name in self.df['api_name'].unique():
            api_data = self.df[self.df['api_name'] == api_name]
            ax1.plot(api_data['concurrency'], api_data['requests_per_sec'], 
                    marker='o', label=api_name, linewidth=2)
        
        ax1.set_xlabel('Concurrencia')
        ax1.set_ylabel('Requests/segundo')
        ax1.set_title('Throughput vs Concurrencia')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        # 2. Latencia Media vs Concurrencia
        ax2 = axes[0, 1]
        for api_name in self.df['api_name'].unique():
            api_data = self.df[self.df['api_name'] == api_name]
            ax2.plot(api_data['concurrency'], api_data['latency_mean_ms'], 
                    marker='s', label=api_name, linewidth=2)
        
        ax2.set_xlabel('Concurrencia')
        ax2.set_ylabel('Latencia Media (ms)')
        ax2.set_title('Latencia Media vs Concurrencia')
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        
        # 3. Latencia P95 vs Concurrencia
        ax3 = axes[1, 0]
        for api_name in self.df['api_name'].unique():
            api_data = self.df[self.df['api_name'] == api_name]
            ax3.plot(api_data['concurrency'], api_data['latency_p95_ms'], 
                    marker='^', label=api_name, linewidth=2)
        
        ax3.set_xlabel('Concurrencia')
        ax3.set_ylabel('Latencia P95 (ms)')
        ax3.set_title('Latencia P95 vs Concurrencia')
        ax3.legend()
        ax3.grid(True, alpha=0.3)
        
        # 4. Comparación de rendimiento por API
        ax4 = axes[1, 1]
        # Usar datos de concurrencia máxima para comparación
        max_concurrency = self.df['concurrency'].max()
        max_conc_data = self.df[self.df['concurrency'] == max_concurrency]
        
        x_pos = np.arange(len(max_conc_data))
        ax4.bar(x_pos, max_conc_data['requests_per_sec'], 
               color=sns.color_palette("husl", len(max_conc_data)))
        ax4.set_xlabel('API')
        ax4.set_ylabel('Requests/segundo')
        ax4.set_title(f'Throughput Máximo (Concurrencia: {max_concurrency})')
        ax4.set_xticks(x_pos)
        ax4.set_xticklabels(max_conc_data['api_name'], rotation=45)
        
        plt.tight_layout()
        plt.savefig('benchmark_results.png', dpi=300, bbox_inches='tight')
        print("📈 Gráfico guardado como: benchmark_results.png")
    
    def generate_summary_table(self) -> None:
        """Genera una tabla resumen de los resultados"""
        if self.df is None or self.df.empty:
            print("❌ No hay datos para generar tabla")
            return
            
        print("\n📋 TABLA RESUMEN DE RESULTADOS")
        print("=" * 80)
        
        # Agrupar por API y calcular estadísticas
        summary = self.df.groupby('api_name').agg({
            'requests_per_sec': ['mean', 'max'],
            'latency_mean_ms': ['mean', 'min'],
            'latency_p95_ms': ['mean', 'max']
        }).round(2)
        
        # Renombrar columnas para mejor legibilidad
        summary.columns = [
            'RPS_Avg', 'RPS_Max', 
            'Lat_Mean_Avg', 'Lat_Mean_Min',
            'Lat_P95_Avg', 'Lat_P95_Max'
        ]
        
        print(summary.to_string())
        
        # Guardar tabla como CSV
        summary.to_csv('benchmark_summary.csv')
        print("\n💾 Tabla resumen guardada como: benchmark_summary.csv")
    
    def calculate_derivatives(self) -> None:
        """Calcula derivadas T'(x) y T''(x) para análisis de rendimiento"""
        print("\n🔬 Calculando derivadas de latencia...")
        
        for api_name in self.df['api_name'].unique():
            api_data = self.df[self.df['api_name'] == api_name].sort_values('concurrency')
            
            if len(api_data) < 2:
                continue
                
            # Calcular primera derivada (cambio de latencia)
            x = api_data['concurrency'].values
            y = api_data['latency_mean_ms'].values
            
            # Primera derivada (aproximación por diferencias finitas)
            dy_dx = np.gradient(y, x)
            
            # Segunda derivada
            d2y_dx2 = np.gradient(dy_dx, x)
            
            print(f"\n📊 {api_name.upper()}:")
            print(f"  T'(x) - Cambio de latencia:")
            for i, (conc, deriv) in enumerate(zip(x, dy_dx)):
                print(f"    Concurrencia {conc}: {deriv:.3f} ms/conc")
            
            print(f"  T''(x) - Aceleración:")
            for i, (conc, deriv2) in enumerate(zip(x, d2y_dx2)):
                print(f"    Concurrencia {conc}: {deriv2:.3f} ms/conc²")
    
    def run_analysis(self) -> None:
        """Ejecuta el análisis completo"""
        print("🚀 Iniciando análisis de resultados de benchmark")
        print("=" * 50)
        
        self.load_results()
        self.create_dataframe()
        self.generate_plots()
        self.generate_summary_table()
        self.calculate_derivatives()
        
        print("\n🎉 Análisis completado!")
        print("📁 Archivos generados:")
        print("  - benchmark_results.png (gráficos)")
        print("  - benchmark_summary.csv (tabla resumen)")

if __name__ == "__main__":
    analyzer = BenchmarkAnalyzer()
    analyzer.run_analysis() 