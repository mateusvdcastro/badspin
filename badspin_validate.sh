#!/usr/bin/env bash

set -euo pipefail


SERIAL="YXV45P8HLV85Q8NN"
VMLINUX=""
SKIP_TTY=0
ADB_IP=""
ADB_PORT="5555"

while [[ $# -gt 0 ]]; do
    case $1 in
        --serial)
            SERIAL="$2"
            shift 2
            ;;
        --vmlinux)
            VMLINUX="$2"
            shift 2
            ;;
        --skip-tty)
            SKIP_TTY=1
            shift
            ;;
        --adb-ip)
            ADB_IP="$2"
            shift 2
            ;;
        --adb-port)
            ADB_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Uso: $0 [--serial SERIAL] [--vmlinux /path/vmlinux] [--skip-tty] [--adb-ip IP] [--adb-port PORT]"
            echo "  --serial SERIAL    : Device serial number"
            echo "  --vmlinux PATH     : Path to vmlinux file"
            echo "  --skip-tty         : Skip TTY setup"
            echo "  --adb-ip IP        : Connect to device via TCP/IP (requires --adb-port)"
            echo "  --adb-port PORT    : ADB TCP port (default: 5555)"
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

ADB=(adb)
[[ -n "$SERIAL" ]] && ADB+=(-s "$SERIAL")

connect_adb_tcpip() {
  if [[ -n "$ADB_IP" ]]; then
    log "Connecting to ADB via TCP/IP: $ADB_IP:$ADB_PORT"
    
    # Try to connect to the device
    if adb connect "$ADB_IP:$ADB_PORT" >/dev/null 2>&1; then
      log "Successfully connected to $ADB_IP:$ADB_PORT"
      
      # Update SERIAL to use the TCP/IP connection
      SERIAL="$ADB_IP:$ADB_PORT"
      ADB=(adb -s "$SERIAL")
      
      # Verify connection
      if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
        echo "Erro: Failed to establish stable connection to $ADB_IP:$ADB_PORT" >&2
        exit 2
      fi
    else
      echo "Erro: Failed to connect to $ADB_IP:$ADB_PORT" >&2
      echo "Make sure the device has TCP/IP debugging enabled and is reachable" >&2
      exit 2
    fi
  fi
}


ts() {
    date +"[%Y-%m-%d %H:%M:%S] $*"
}
OUTDIR="badspin-validate-logs-$(ts)"
mkdir -p "$OUTDIR"

log() { echo "[$(date +%H:%M:%S)] $*"; }
save() { # save "desc" "cmd..." -> runs cmd, tee to file
  local desc="$1"; shift
  local fn="$OUTDIR/$desc"
  log "Coletando: $desc"
  ( "${ADB[@]}" shell "$@" ) > "$fn" 2>&1 || true
}

adbshell() { "${ADB[@]}" shell "$@"; }

require_adb() {
  command -v adb >/dev/null || { echo "adb não encontrado no PATH"; exit 2; }
  if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
    echo "Erro: Dispositivo '$SERIAL' não encontrado ou não conectado"
    echo "Dispositivos disponíveis:"
    adb devices
    exit 2
  fi
}


# ------ Start ------
connect_adb_tcpip
require_adb
log "Dispositivo: $("${ADB[@]}" shell getprop ro.product.device | tr -d '\r')"

mkdir -p "$OUTDIR"
save "props.txt" getprop
save "uname.txt" uname -a
save "proc_version.txt" cat /proc/version
save "security_patch.txt" getprop ro.build.version.security_patch
save "cmdline.txt" cat /proc/cmdline

# 1) Config do kernel (running.config se disponível)
log "Tentando extrair /proc/config.gz..."
if adbshell test -e /proc/config.gz ; then
  "${ADB[@]}" shell "zcat /proc/config.gz" > "$OUTDIR/running.config" || true
else
  log "/proc/config.gz indisponível (ok em alguns builds)."
fi

# 2) QSpinlock e SMP
if [[ -f "$OUTDIR/running.config" ]]; then
  grep -E 'CONFIG_QUEUED_SPINLOCKS|CONFIG_SMP' "$OUTDIR/running.config" > "$OUTDIR/qspinlock_smp.config" || true
else
  save "qspinlock_smp.config" sh -c "zcat /proc/config.gz 2>/dev/null | grep -E 'CONFIG_QUEUED_SPINLOCKS|CONFIG_SMP' || true"
fi
save "kallsyms_qspin.txt" sh -c "cat /proc/kallsyms | grep -E 'queued_spin_lock|queued_spin_unlock|qspin' | head -n 50"



zip_out
log "Concluído. Veja $OUTDIR para todos os artefatos e $OUTDIR.zip para compartilhar."