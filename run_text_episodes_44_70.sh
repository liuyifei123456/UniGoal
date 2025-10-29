#!/bin/bash

# Script to run text-goal navigation for episodes 44-70
# Usage: bash run_text_episodes_44_70.sh

# Set error handling
set -e

# Configuration
GOAL_TYPE="text"
START_EPISODE=44
END_EPISODE=70
LOG_DIR="./outputs/experiments/experiment_0/log"
RESULTS_DIR="./outputs/experiments/experiment_0/results"

# Create directories
mkdir -p ${LOG_DIR}
mkdir -p ${RESULTS_DIR}

# Log file for this batch
BATCH_LOG="${LOG_DIR}/batch_episodes_${START_EPISODE}_${END_EPISODE}.log"

echo "=======================================" | tee -a ${BATCH_LOG}
echo "Starting Text-Goal Navigation Batch" | tee -a ${BATCH_LOG}
echo "Episodes: ${START_EPISODE} to ${END_EPISODE}" | tee -a ${BATCH_LOG}
echo "Start time: $(date)" | tee -a ${BATCH_LOG}
echo "=======================================" | tee -a ${BATCH_LOG}
echo "" | tee -a ${BATCH_LOG}

# Counter for tracking progress
total_episodes=$((END_EPISODE - START_EPISODE + 1))
current_count=0

# Run episodes sequentially
for episode_id in $(seq ${START_EPISODE} ${END_EPISODE}); do
    current_count=$((current_count + 1))
    
    echo "-----------------------------------" | tee -a ${BATCH_LOG}
    echo "[${current_count}/${total_episodes}] Running Episode: ${episode_id}" | tee -a ${BATCH_LOG}
    echo "Time: $(date)" | tee -a ${BATCH_LOG}
    echo "-----------------------------------" | tee -a ${BATCH_LOG}
    
    # Run the episode
    episode_log="${LOG_DIR}/episode_${episode_id}.log"
    
    if python main.py --goal_type ${GOAL_TYPE} --episode_id ${episode_id} 2>&1 | tee ${episode_log}; then
        echo "✓ Episode ${episode_id} completed successfully" | tee -a ${BATCH_LOG}
    else
        echo "✗ Episode ${episode_id} failed with error code $?" | tee -a ${BATCH_LOG}
        echo "  Check log: ${episode_log}" | tee -a ${BATCH_LOG}
        # Continue with next episode even if this one failed
        continue
    fi
    
    echo "" | tee -a ${BATCH_LOG}
done

echo "" | tee -a ${BATCH_LOG}
echo "=======================================" | tee -a ${BATCH_LOG}
echo "Batch Run Completed" | tee -a ${BATCH_LOG}
echo "End time: $(date)" | tee -a ${BATCH_LOG}
echo "Total episodes attempted: ${total_episodes}" | tee -a ${BATCH_LOG}
echo "=======================================" | tee -a ${BATCH_LOG}

# Display summary
echo ""
echo "All episodes completed!"
echo "Logs saved in: ${LOG_DIR}/"
echo "Videos saved in: ./outputs/experiments/experiment_0/visualization/videos/"
echo ""
echo "To view the batch log:"
echo "  cat ${BATCH_LOG}"
