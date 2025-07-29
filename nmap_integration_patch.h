#ifndef NMAP_INTEGRATION_PATCH_H
#define NMAP_INTEGRATION_PATCH_H

#include <iostream>
#include <vector>
#include <thread>
#include <atomic>
#include <chrono>
#include <mutex>
#include "scan_lists.h" // Added to define stype

// 前向聲明，避免包含完整的 Nmap 頭文件
struct Target;
struct scan_lists;
struct timeout_info;
struct UltraScanInfo; // 添加 UltraScanInfo 前向聲明

// 全局變量和函數聲明
bool keyWasPressed();
extern struct NmapOps o;

// 全局掃描函數聲明
void doAnyNewProbes(UltraScanInfo *USI);
void waitForResponses(UltraScanInfo *USI);
void processData(UltraScanInfo *USI);
void doAnyPings(UltraScanInfo *USI);
void doAnyOutstandingRetransmits(UltraScanInfo *USI);
void doAnyRetryStackRetransmits(UltraScanInfo *USI);
void begin_sniffer(UltraScanInfo *USI, std::vector<Target *> &Targets);

// stype 已在 scan_lists.h 中定義為枚舉類型，不需要重新定義

namespace NmapIntegration {

// 優化配置結構
struct OptimizationConfig {
    bool enabled = false;
    int parallel_workers = 20;
    double adaptive_timeout_factor = 0.8;
    bool performance_monitoring = true;
    bool batch_processing = true;
    bool smart_retry = true;
    
    // 性能指標
    std::atomic<int> probes_sent{0};
    std::atomic<int> responses_received{0};
    std::atomic<int> timeouts{0};
    std::atomic<int> errors{0};
};

// 優化包裝器類
class OptimizationWrapper {
public:
    OptimizationWrapper();
    ~OptimizationWrapper();
    
    // 設置優化模式
    void set_optimization_enabled(bool enabled);
    void set_parallel_workers(int workers);
    void set_adaptive_timeout_factor(double factor);
    
    // 優化版本的 ultra_scan
    void ultra_scan_optimized(std::vector<Target *> &Targets, 
                             const struct scan_lists *ports, 
                             stype scantype, 
                             struct timeout_info *to = NULL);
    
    // 性能監控
    void start_performance_monitoring();
    void stop_performance_monitoring();
    void print_performance_report();
    
    // 獲取配置
    OptimizationConfig& get_config() { return config; }

private:
    OptimizationConfig config;
    std::chrono::high_resolution_clock::time_point start_time;
    std::chrono::high_resolution_clock::time_point end_time;
    
    // 內部優化函數
    void apply_optimized_timeouts(struct timeout_info *to);
    void apply_batch_processing(std::vector<Target *> &Targets);
    void apply_smart_retry_logic();
    
    // 並行掃描函數
    void parallel_scan_targets(std::vector<Target *> &Targets, 
                              const struct scan_lists *ports, 
                              stype scantype, 
                              struct timeout_info *to);
    void optimized_single_target_scan(std::vector<Target *> &Targets, 
                                     const struct scan_lists *ports, 
                                     stype scantype, 
                                     struct timeout_info *to);
    
    // 激進掃描函數
    void aggressive_single_target_scan(std::vector<Target *> &Targets, 
                                      const struct scan_lists *ports, 
                                      stype scantype, 
                                      struct timeout_info *to);
    void apply_aggressive_scan_strategy(std::vector<Target *> &Targets, 
                                       const struct scan_lists *ports, 
                                       stype scantype);
    
    // 全新優化掃描引擎函數
    void optimized_scan_engine(std::vector<Target *> &Targets, 
                              const struct scan_lists *ports, 
                              stype scantype, 
                              struct timeout_info *to);
    void preprocess_targets(std::vector<Target *> &Targets, 
                           const struct scan_lists *ports, 
                           stype scantype);
    void batch_port_scan(std::vector<Target *> &Targets, 
                        const struct scan_lists *ports, 
                        stype scantype, 
                        struct timeout_info *to);
    void parallel_service_detection(std::vector<Target *> &Targets, 
                                   const struct scan_lists *ports, 
                                   stype scantype);
    void postprocess_results(std::vector<Target *> &Targets);
    
    // 優化掃描引擎核心函數
    void execute_optimized_scan_like_ultra_scan(std::vector<Target *> &Targets, 
                                               const struct scan_lists *ports, 
                                               stype scantype, 
                                               struct timeout_info *to);
    void optimize_scan_parameters_for_engine(UltraScanInfo *USI);
    void doAnyNewProbesOptimized(UltraScanInfo *USI);
    void waitForResponsesOptimized(UltraScanInfo *USI);
    void processDataOptimized(UltraScanInfo *USI);
    
    // 優化設置函數
    void apply_optimization_settings(std::vector<Target *> &Targets, 
                                   const struct scan_lists *ports, 
                                   stype scantype);
    void optimize_scan_parameters(std::vector<Target *> &Targets, 
                                 const struct scan_lists *ports, 
                                 stype scantype);
    void preset_scan_strategy(std::vector<Target *> &Targets, 
                             const struct scan_lists *ports, 
                             stype scantype);
    
    // 輔助函數
    void predict_port_states(Target *target, const struct scan_lists *ports);
    void optimize_scan_order(Target *target, const struct scan_lists *ports);
    void preset_common_ports(Target *target);
    std::vector<int> create_port_groups(const struct scan_lists *ports);
    void scan_port_group(std::vector<Target *> &Targets, 
                        int port_group, 
                        stype scantype, 
                        struct timeout_info *to);
    void scan_ports_for_target(Target *target, 
                              int port_group, 
                              stype scantype, 
                              struct timeout_info *to);
    void detect_services_optimized(Target *target, 
                                  const struct scan_lists *ports, 
                                  stype scantype);
    void validate_scan_results(Target *target);
    void optimize_output_format(Target *target);
    void cleanup_temporary_data(Target *target);
};

// 優化選項類
class OptimizationOptions {
public:
    static void handle_optimization_options(int argc, char *argv[]);
    static void initialize_optimization_modules();
    static void cleanup_optimization_modules();
    
    // 解析命令行選項
    static bool parse_optimization_option(const char *option);
    
private:
    static void print_optimization_help();
};

// 全局實例
extern OptimizationWrapper g_optimization_wrapper;

// 集成函數
void ultra_scan_optimized(std::vector<Target *> &Targets, 
                         const struct scan_lists *ports, 
                         stype scantype, 
                         struct timeout_info *to = NULL);

void handle_optimization_options(int argc, char *argv[]);
void initialize_optimization_modules();
void cleanup_optimization_modules();

// 性能報告函數
void print_optimization_performance_report();

} // namespace NmapIntegration

#endif // NMAP_INTEGRATION_PATCH_H 