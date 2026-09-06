using System.Management;

namespace six_eyes;

internal enum UsbDeviceChangeKind
{
    Attached,
    Removed
}

internal sealed record UsbDeviceChange(UsbDeviceChangeKind Kind, string PnpDeviceId);

internal sealed class UsbDeviceMonitor : IDisposable
{
    private readonly Action<UsbDeviceChange> changed;
    private readonly Action refreshRequested;
    private readonly object sync = new();
    private ManagementEventWatcher? attachWatcher;
    private ManagementEventWatcher? removeWatcher;
    private CancellationTokenSource? refreshDelay;
    private bool disposed;

    public UsbDeviceMonitor(Action<UsbDeviceChange> changed, Action refreshRequested)
    {
        this.changed = changed;
        this.refreshRequested = refreshRequested;
    }

    public void Start()
    {
        lock (sync)
        {
            ObjectDisposedException.ThrowIf(disposed, this);
            if (attachWatcher is not null || removeWatcher is not null)
                return;

            try
            {
                attachWatcher = CreateWatcher("__InstanceCreationEvent", UsbDeviceChangeKind.Attached);
                removeWatcher = CreateWatcher("__InstanceDeletionEvent", UsbDeviceChangeKind.Removed);
                attachWatcher.Start();
                removeWatcher.Start();
            }
            catch
            {
                StopWatcher(attachWatcher);
                StopWatcher(removeWatcher);
                attachWatcher = null;
                removeWatcher = null;
                throw;
            }
        }
    }

    public void Dispose()
    {
        ManagementEventWatcher? attach;
        ManagementEventWatcher? remove;
        CancellationTokenSource? delay;

        lock (sync)
        {
            if (disposed)
                return;

            disposed = true;
            attach = attachWatcher;
            remove = removeWatcher;
            delay = refreshDelay;
            attachWatcher = null;
            removeWatcher = null;
            refreshDelay = null;
        }

        delay?.Cancel();
        delay?.Dispose();
        StopWatcher(attach);
        StopWatcher(remove);
    }

    private ManagementEventWatcher CreateWatcher(string eventType, UsbDeviceChangeKind changeKind)
    {
        var query = new WqlEventQuery(
            $"SELECT * FROM {eventType} WITHIN 2 " +
            "WHERE TargetInstance ISA 'Win32_PnPEntity' " +
            "AND TargetInstance.PNPDeviceID LIKE '%USB%'");
        var watcher = new ManagementEventWatcher(query);
        watcher.EventArrived += (_, eventArgs) => OnUsbChanged(changeKind, eventArgs);
        return watcher;
    }

    private void OnUsbChanged(UsbDeviceChangeKind changeKind, EventArrivedEventArgs eventArgs)
    {
        CancellationTokenSource delay;
        CancellationToken cancellationToken;
        CancellationTokenSource? previous;

        lock (sync)
        {
            if (disposed)
                return;

            delay = new CancellationTokenSource();
            cancellationToken = delay.Token;
            previous = refreshDelay;
            refreshDelay = delay;
        }

        var target = eventArgs.NewEvent["TargetInstance"] as ManagementBaseObject;
        var pnpDeviceId = target?["PNPDeviceID"]?.ToString() ?? "";
        changed(new UsbDeviceChange(changeKind, pnpDeviceId));

        previous?.Cancel();
        previous?.Dispose();
        _ = NotifyAfterDelayAsync(delay, cancellationToken);
    }

    private async Task NotifyAfterDelayAsync(CancellationTokenSource delay, CancellationToken cancellationToken)
    {
        try
        {
            await Task.Delay(750, cancellationToken).ConfigureAwait(false);
            lock (sync)
            {
                if (disposed || cancellationToken.IsCancellationRequested)
                    return;
            }
            refreshRequested();
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            lock (sync)
            {
                if (ReferenceEquals(refreshDelay, delay))
                    refreshDelay = null;
            }
            delay.Dispose();
        }
    }

    private static void StopWatcher(ManagementEventWatcher? watcher)
    {
        if (watcher is null)
            return;

        try
        {
            watcher.Stop();
        }
        catch (ManagementException)
        {
        }
        finally
        {
            watcher.Dispose();
        }
    }
}
