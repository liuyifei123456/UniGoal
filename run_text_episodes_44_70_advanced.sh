#!/bin/bash

# Advanced script to run text-goal navigation for episodes 44-70
# Features: parallel execution, resume capability, progress tracking
# Usage: 
#   Sequential: bash run_text_episodes_44_70_advanced.sh
#   Parallel:   bash run_text_episodes_44_70_advanced.sh --parallel 4

# Configuration
GOAL_TYPE="text"
START_EPISODE=47
END_EPISODE=47
LOG_DIR="./outputs/experiments/experiment_0/log"
RESULTS_DIR="./outputs/experiments/experiment_0/results"
PROGRESS_FILE="./outputs/experiments/experiment_0/.progress_44_70.txt"

# Parse command line arguments
PARALLEL_JOBS=1  # Default: sequential
RESUME=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --parallel)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --resume)
            RESUME=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--parallel N] [--resume]"
            exit 1
            ;;
    esac
done

# Create directories
mkdir -p ${LOG_DIR}
mkdir -p ${RESULTS_DIR}

# Initialize or load progress file
if [ "$RESUME" = true ] && [ -f "$PROGRESS_FILE" ]; then
    echo "Resuming from previous run..."
    source "$PROGRESS_FILE"
else
    echo "# Progress tracking file" > "$PROGRESS_FILE"
    echo "COMPLETED_EPISODES=()" >> "$PROGRESS_FILE"
fi

# Load completed episodes
source "$PROGRESS_FILE"

# Function to run a single episode
run_episode() {
    local episode_id=$1
    local episode_log="${LOG_DIR}/episode_${episode_id}.log"
    
    # Check if already completed
    if [[ " ${COMPLETED_EPISODES[@]} " =~ " ${episode_id} " ]]; then
        echo "⊙ Episode ${episode_id} already completed (skipping)"
        return 0
    fi
    
    echo "▶ Starting Episode ${episode_id} at $(date '+%H:%M:%S')"
    
    if python main.py --goal_type ${GOAL_TYPE} --episode_id ${episode_id} > ${episode_log} 2>&1; then
        echo "✓ Episode ${episode_id} completed successfully at $(date '+%H:%M:%S')"
        
        # Mark as completed
        echo "COMPLETED_EPISODES+=(${episode_id})" >> "$PROGRESS_FILE"
        
        return 0
    else
        local exit_code=$?
        echo "✗ Episode ${episode_id} failed with exit code ${exit_code}"
        echo "  Log: ${episode_log}"
        return ${exit_code}
    fi
}

# Export function for parallel execution
export -f run_episode
export GOAL_TYPE LOG_DIR RESULTS_DIR PROGRESS_FILE
export COMPLETED_EPISODES

# Main execution
BATCH_LOG="${LOG_DIR}/batch_episodes_${START_EPISODE}_${END_EPISODE}.log"

{
    echo "======================================="
    echo "Text-Goal Navigation Batch Runner"
    echo "======================================="
    echo "Episodes: ${START_EPISODE} to ${END_EPISODE}"
    echo "Parallel jobs: ${PARALLEL_JOBS}"
    echo "Resume mode: ${RESUME}"
    echo "Start time: $(date)"
    echo "======================================="
    echo ""
} | tee ${BATCH_LOG}

# Generate episode list
EPISODES=$(seq ${START_EPISODE} ${END_EPISODE})
total_episodes=$(echo ${EPISODES} | wc -w)

echo "Total episodes to run: ${total_episodes}" | tee -a ${BATCH_LOG}
echo "" | tee -a ${BATCH_LOG}

# Run episodes
if [ ${PARALLEL_JOBS} -eq 1 ]; then
    # Sequential execution
    echo "Running sequentially..." | tee -a ${BATCH_LOG}
    current=0
    for episode_id in ${EPISODES}; do
        current=$((current + 1))
        echo "[${current}/${total_episodes}] Processing episode ${episode_id}" | tee -a ${BATCH_LOG}
        run_episode ${episode_id} 2>&1 | tee -a ${BATCH_LOG}
        echo "" | tee -a ${BATCH_LOG}
    done
else
    # Parallel execution using GNU parallel or xargs
    echo "Running ${PARALLEL_JOBS} episodes in parallel..." | tee -a ${BATCH_LOG}
    
    if command -v parallel &> /dev/null; then
        # Use GNU parallel if available
        echo ${EPISODES} | tr ' ' '\n' | parallel -j ${PARALLEL_JOBS} run_episode {} 2>&1 | tee -a ${BATCH_LOG}
    else
        # Fallback to xargs
        echo "GNU parallel not found, using xargs (limited features)" | tee -a ${BATCH_LOG}
        echo ${EPISODES} | tr ' ' '\n' | xargs -P ${PARALLEL_JOBS} -I {} bash -c "run_episode {}" 2>&1 | tee -a ${BATCH_LOG}
    fi
fi

# Final summary
{
    echo ""
    echo "======================================="
    echo "Batch Run Summary"
    echo "======================================="
    echo "End time: $(date)"
    
    # Count completed episodes
    source "$PROGRESS_FILE"
    completed_count=${#COMPLETED_EPISODES[@]}
    echo "Completed: ${completed_count}/${total_episodes} episodes"
    
    # Calculate success rate
    if [ ${total_episodes} -gt 0 ]; then
        success_rate=$((completed_count * 100 / total_episodes))
        echo "Success rate: ${success_rate}%"
    fi
    
    echo "======================================="
    echo ""
    echo "Results saved in:"
    echo "  - Logs: ${LOG_DIR}/"
    echo "  - Videos: ./outputs/experiments/experiment_0/visualization/videos/"
    echo "  - Progress: ${PROGRESS_FILE}"
    echo ""
    
    if [ ${completed_count} -lt ${total_episodes} ]; then
        echo "To resume failed episodes, run:"
        echo "  bash $0 --resume"
        echo ""
    fi
} | tee -a ${BATCH_LOG}
