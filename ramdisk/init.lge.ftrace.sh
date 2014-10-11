#!/system/bin/sh

FTRACE_KICK_FILE=/data/ftrace_kick
DEBUGFS_PATH=/sys/kernel/debug
TRACING_PATH=$DEBUGFS_PATH/tracing
NOTRACE_PATH=$TRACING_PATH/set_ftrace_notrace
PERSISTENT_TRACE_PATH=$DEBUGFS_PATH/persistent_trace

if [ -a $FTRACE_KICK_FILE ]; then
	echo "msm_read_timer_count" > $NOTRACE_PATH
	echo "read_current_timer" >> $NOTRACE_PATH
	echo "read_current_timer_delay_loop" >> $NOTRACE_PATH
	echo "persistent" > $TRACING_PATH/current_tracer
fi
