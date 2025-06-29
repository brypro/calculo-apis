#!/usr/bin/env python3
"""
Generador de Datos Simulados para Análisis Matemático
Basado en los benchmarks reales ejecutados manualmente
"""

import pandas as pd
import numpy as np
from datetime import datetime

def generate_realistic_data():
    """Genera datos simulados basados en benchmarks reales"""
    
    # Datos base observados en benchmarks manuales
    base_data = {
        'Go': {'base_latency': 0.7, 'growth_factor': 0.002, 'noise': 0.1},
        'Python': {'base_latency': 1.2, 'growth_factor': 0.005, 'noise': 0.2},
        'NodeJS': {'base_latency': 10.27, 'growth_factor': 0.015, 'noise': 0.5},
        'DotNet': {'base_latency': 0.8, 'growth_factor': 0.003, 'noise': 0.15}
    }
    
    # Puntos de concurrencia
    concurrency_points = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    replicas = 3
    
    all_data = []
    
    for api_name, params in base_data.items():
        print(f"Generando datos para {api_name} API...")
        
        for concurrency in concurrency_points:
            for replica in range(1, replicas + 1):
                # Modelo cuadrático: T(x) = base + growth_factor * x^2 + noise
                base_latency = params['base_latency']
                growth = params['growth_factor'] * (concurrency ** 1.5)  # Crecimiento sub-cuadrático
                noise = np.random.normal(0, params['noise'])
                
                latency_p95 = max(0.1, base_latency + growth + noise)
                
                # Calcular RPS basado en latencia (relación inversa aproximada)
                if api_name == 'Go':
                    rps_base = 15000
                elif api_name == 'DotNet':
                    rps_base = 12000
                elif api_name == 'Python':
                    rps_base = 8000
                else:  # NodeJS
                    rps_base = 1000
                
                # RPS decrece con latencia y concurrencia
                rps = max(50, rps_base / (1 + latency_p95 * 0.1) * (concurrency / 100))
                rps += np.random.normal(0, rps * 0.05)  # 5% de ruido
                
                # Error rate aumenta con concurrencia
                error_rate = max(0, min(5, (concurrency - 50) * 0.1 + np.random.normal(0, 0.5)))
                
                all_data.append({
                    'API': api_name,
                    'Concurrency': concurrency,
                    'Replica': replica,
                    'RequestsPerSec': round(rps, 2),
                    'LatencyMean': round(latency_p95 * 0.8, 2),
                    'LatencyP50': round(latency_p95 * 0.7, 2),
                    'LatencyP95': round(latency_p95, 2),
                    'LatencyP99': round(latency_p95 * 1.3, 2),
                    'ErrorRate': round(max(0, error_rate), 2),
                    'Success': True
                })
    
    return pd.DataFrame(all_data)

def main():
    """Función principal"""
    print("🔬 GENERANDO DATOS SIMULADOS PARA ANÁLISIS MATEMÁTICO")
    print("=" * 60)
    
    # Generar datos
    df = generate_realistic_data()
    
    # Guardar CSV
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    csv_filename = f"mathematical-benchmark-{timestamp}.csv"
    df.to_csv(csv_filename, index=False, encoding='utf-8')
    
    print(f"\n📊 DATOS GENERADOS:")
    print(f"Total de registros: {len(df)}")
    print(f"APIs: {df['API'].unique()}")
    print(f"Rango de concurrencia: {df['Concurrency'].min()}-{df['Concurrency'].max()}")
    
    # Mostrar resumen por API
    print(f"\n📈 RESUMEN POR API:")
    for api in df['API'].unique():
        api_data = df[df['API'] == api]
        avg_latency = api_data['LatencyP95'].mean()
        min_latency = api_data['LatencyP95'].min()
        max_latency = api_data['LatencyP95'].max()
        avg_rps = api_data['RequestsPerSec'].mean()
        
        print(f"{api}:")
        print(f"  Latencia P95: {avg_latency:.2f}ms (rango: {min_latency:.2f}-{max_latency:.2f})")
        print(f"  RPS promedio: {avg_rps:.0f}")
        print(f"  Puntos de datos: {len(api_data)}")
    
    print(f"\n💾 Archivo guardado: {csv_filename}")
    print(f"🔬 Listo para análisis matemático!")
    
    # Preview de datos
    print(f"\n📋 PREVIEW:")
    sample_data = df.groupby(['API', 'Concurrency'])['LatencyP95'].mean().reset_index()
    print(sample_data.pivot(index='Concurrency', columns='API', values='LatencyP95').round(2))

if __name__ == "__main__":
    main() 