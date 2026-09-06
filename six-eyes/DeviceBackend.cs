using Qt.MetaObject;
using Qt.Quick;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Text.Json;

namespace six_eyes;

[QObject]
[QmlElement(Name = "DeviceBackend", Singleton = true)]
public sealed class DeviceBackend : INotifyPropertyChanged, IDisposable
{
    private readonly DeviceOperationCoordinator operationCoordinator = new();
    private readonly MtpDataBankService dataBankService = new();
    private readonly UsbDeviceMonitor deviceMonitor;
    private readonly SynchronizationContext? synchronizationContext;
    private readonly List<string> sessionFiles = [];
    private bool disposed;
    private string activeDeviceId = "";
    private bool connected;
    private string deviceName = "";
    private string filesJson = "[]";
    private string sessionFilesJson = "[]";
    private bool busy;
    private double progress;
    private string status = "Waiting for device";
    private string error = "";

    internal static DeviceBackend? Current { get; private set; }

    public DeviceBackend()
    {
        Current = this;
        synchronizationContext = SynchronizationContext.Current;
        deviceMonitor = new UsbDeviceMonitor(OnUsbDeviceChanged, Refresh);

        try
        {
            deviceMonitor.Start();
        }
        catch (Exception exception)
        {
            Error = $"USB monitoring unavailable: {exception.Message}";
        }

        Refresh();
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public bool Connected
    {
        get => connected;
        private set => SetField(ref connected, value);
    }

    public string DeviceName
    {
        get => deviceName;
        private set => SetField(ref deviceName, value);
    }

    public string FilesJson
    {
        get => filesJson;
        private set => SetField(ref filesJson, value);
    }

    public string SessionFilesJson
    {
        get => sessionFilesJson;
        private set => SetField(ref sessionFilesJson, value);
    }

    public bool Busy
    {
        get => busy;
        private set => SetField(ref busy, value);
    }

    public double Progress
    {
        get => progress;
        private set => SetField(ref progress, value);
    }

    public string Status
    {
        get => status;
        private set => SetField(ref status, value);
    }

    public string Error
    {
        get => error;
        private set => SetField(ref error, value);
    }

    public void Refresh()
    {
        _ = RunOperationAsync("Checking device", () =>
        {
            var snapshot = dataBankService.Refresh();
            return snapshot is null
                ? SetDisconnected
                : () => ApplyRefreshSnapshot(snapshot);
        }, showBusy: false);
    }

    public void RefreshDirectory()
    {
        _ = RunOperationAsync("Reading data bank", () =>
        {
            var snapshot = dataBankService.RefreshDirectory();
            return () => ApplySnapshot(snapshot, "Data bank ready");
        });
    }

    public void Upload(string sourceUrl)
    {
        _ = RunOperationAsync("Uploading file", () =>
        {
            var sourcePath = PathValidator.LocalPath(sourceUrl);
            var result = dataBankService.Upload(sourcePath);
            return () =>
            {
                ApplySnapshot(result.Snapshot, $"Uploaded {result.StoredFileName}");
                sessionFiles.Add(result.StoredFileName);
                SessionFilesJson = JsonSerializer.Serialize(sessionFiles);
                Progress = 1;
            };
        });
    }

    public void Download(string fileName, string destinationUrl)
    {
        _ = RunOperationAsync("Downloading file", () =>
        {
            PathValidator.ValidateFileName(fileName);
            var destinationPath = PathValidator.LocalPath(destinationUrl);
            var currentDeviceName = dataBankService.Download(fileName, destinationPath);
            return () =>
            {
                Connected = true;
                DeviceName = currentDeviceName;
                Progress = 1;
                Status = $"Downloaded {fileName}";
            };
        });
    }

    public void DownloadAll(string destinationUrl)
    {
        _ = RunOperationAsync("Downloading all files", () =>
        {
            var destinationDirectory = PathValidator.LocalPath(destinationUrl);
            var result = dataBankService.DownloadAll(destinationDirectory);
            return () =>
            {
                Connected = true;
                DeviceName = result.DeviceName;
                Progress = 1;
                Status = $"Downloaded {result.FileCount} files";
            };
        });
    }

    public void ClearError()
    {
        Error = "";
    }

    public void Dispose()
    {
        if (disposed)
            return;

        disposed = true;
        deviceMonitor.Dispose();
        operationCoordinator.Dispose();
        if (ReferenceEquals(Current, this))
            Current = null;
    }

    private async Task RunOperationAsync(string operationStatus, Func<Action> operation, bool showBusy = true)
    {
        if (disposed)
            return;

        try
        {
            await operationCoordinator.RunAsync(() =>
                {
                    try
                    {
                        return operation();
                    }
                    catch (Exception exception)
                    {
                        var hasDevice = dataBankService.HasDevice();
                        return () =>
                        {
                            Error = exception.Message;
                            Status = "Operation failed";
                            if (!hasDevice)
                                SetDisconnected();
                        };
                    }
                },
                () => Post(() =>
                {
                    if (showBusy)
                    {
                        Busy = true;
                        Progress = 0;
                        Error = "";
                        Status = operationStatus;
                    }
                }),
                applyResult => Post(() =>
                {
                    applyResult();
                    Busy = false;
                })).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (disposed)
        {
        }
        catch (ObjectDisposedException) when (disposed)
        {
        }
    }

    private void ApplySnapshot(DeviceSnapshot snapshot, string operationStatus)
    {
        UpdateDeviceSession(snapshot);
        Connected = true;
        DeviceName = snapshot.Name;
        FilesJson = JsonSerializer.Serialize(snapshot.Files);
        Status = operationStatus;
    }

    private void ApplyRefreshSnapshot(DeviceSnapshot snapshot)
    {
        var wasConnected = Connected;
        UpdateDeviceSession(snapshot);
        Connected = true;
        DeviceName = snapshot.Name;
        FilesJson = JsonSerializer.Serialize(snapshot.Files);
        if (!wasConnected)
            Status = "Device connected";
    }

    private void SetDisconnected()
    {
        Connected = false;
        activeDeviceId = "";
        DeviceName = "";
        FilesJson = "[]";
        ClearSessionFiles();
        Status = "Waiting for device";
    }

    private void UpdateDeviceSession(DeviceSnapshot snapshot)
    {
        if (!string.Equals(activeDeviceId, snapshot.Id, StringComparison.OrdinalIgnoreCase))
            ClearSessionFiles();
        activeDeviceId = snapshot.Id;
    }

    private void ClearSessionFiles()
    {
        if (sessionFiles.Count == 0 && SessionFilesJson == "[]")
            return;

        sessionFiles.Clear();
        SessionFilesJson = "[]";
    }

    private void OnUsbDeviceChanged(UsbDeviceChange change)
    {
        if (change.Kind != UsbDeviceChangeKind.Removed ||
            !IsActiveDevice(change.PnpDeviceId))
        {
            return;
        }

        Post(SetDisconnected);
    }

    private bool IsActiveDevice(string pnpDeviceId)
    {
        var activeId = NormalizeDeviceId(activeDeviceId);
        var removedId = NormalizeDeviceId(pnpDeviceId);
        return activeId.Length > 0 && removedId.Length > 0 &&
            (activeId.Contains(removedId, StringComparison.Ordinal) ||
             removedId.Contains(activeId, StringComparison.Ordinal));
    }

    private static string NormalizeDeviceId(string deviceId)
    {
        return string.Concat(deviceId.Where(char.IsLetterOrDigit)).ToUpperInvariant();
    }

    private void Post(Action action)
    {
        if (disposed)
            return;

        if (synchronizationContext is null || SynchronizationContext.Current == synchronizationContext)
        {
            action();
            return;
        }

        synchronizationContext.Post(_ =>
        {
            if (!disposed)
                action();
        }, null);
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return;

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
