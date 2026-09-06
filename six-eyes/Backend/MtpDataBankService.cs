using MediaDevices;

namespace six_eyes;

internal sealed record DeviceSnapshot(string Id, string Name, IReadOnlyList<string> Files);

internal sealed record UploadResult(DeviceSnapshot Snapshot, string StoredFileName);

internal sealed record DownloadAllResult(string DeviceName, int FileCount);

internal sealed class MtpDataBankService
{
    private const string DataBankRelativePath = @"Documents\databank";

    public DeviceSnapshot? Refresh()
    {
        var device = MediaDeviceManager.Instance.GetDevices()?.FirstOrDefault();
        if (device is null)
            return null;

        using (device)
        {
            device.Connect();
            try
            {
                return Snapshot(device);
            }
            finally
            {
                Disconnect(device);
            }
        }
    }

    public DeviceSnapshot RefreshDirectory()
    {
        using var device = GetDevice();
        device.Connect();
        try
        {
            return Snapshot(device);
        }
        finally
        {
            Disconnect(device);
        }
    }

    public UploadResult Upload(string sourcePath)
    {
        if (!File.Exists(sourcePath))
            throw new FileNotFoundException("Selected file no longer exists.", sourcePath);

        using var device = GetDevice();
        device.Connect();
        try
        {
            var targetDirectory = DataBankPath(device);

            if (!device.DirectoryExists(targetDirectory))
                device.CreateDirectory(targetDirectory);

            var storedFileName = UniqueFileName(device, targetDirectory, Path.GetFileName(sourcePath));
            var targetPath = $@"{targetDirectory}\{storedFileName}";
            try
            {
                device.UploadFile(sourcePath, targetPath);
                if (!device.FileExists(targetPath))
                    throw new IOException("Uploaded file could not be verified.");

                var localSize = new FileInfo(sourcePath).Length;
                var remoteSize = unchecked((long)device.GetFileInfo(targetPath).Length);
                if (localSize != remoteSize)
                    throw new IOException($"Uploaded file size differs: local={localSize}, device={remoteSize}.");
            }
            catch
            {
                TryDeleteFile(device, targetPath);
                throw;
            }

            return new UploadResult(Snapshot(device), storedFileName);
        }
        finally
        {
            Disconnect(device);
        }
    }

    public string Download(string fileName, string destinationPath)
    {
        var destinationDirectory = Path.GetDirectoryName(destinationPath);
        if (string.IsNullOrWhiteSpace(destinationDirectory))
            throw new ArgumentException("Choose a valid download destination.", nameof(destinationPath));

        Directory.CreateDirectory(destinationDirectory);
        using var device = GetDevice();
        device.Connect(MediaDeviceAccess.GenericRead, MediaDeviceShare.Write);
        try
        {
            var remotePath = $@"{DataBankPath(device)}\{fileName}";
            if (!device.FileExists(remotePath))
                throw new FileNotFoundException("Selected file does not exist on device.", remotePath);

            DownloadFile(device, remotePath, destinationPath);

            return DeviceName(device);
        }
        finally
        {
            Disconnect(device);
        }
    }

    public DownloadAllResult DownloadAll(string destinationDirectory)
    {
        if (string.IsNullOrWhiteSpace(destinationDirectory))
            throw new ArgumentException("Choose a valid download destination.", nameof(destinationDirectory));

        Directory.CreateDirectory(destinationDirectory);

        using var device = GetDevice();
        device.Connect(MediaDeviceAccess.GenericRead, MediaDeviceShare.Write);
        try
        {
            var files = ListFiles(device);
            var dataBankPath = DataBankPath(device);
            foreach (var fileName in files)
            {
                PathValidator.ValidateFileName(fileName);
                DownloadFile(
                    device,
                    $@"{dataBankPath}\{fileName}",
                    Path.Combine(destinationDirectory, fileName));
            }

            return new DownloadAllResult(DeviceName(device), files.Count);
        }
        finally
        {
            Disconnect(device);
        }
    }

    public bool HasDevice()
    {
        try
        {
            return MediaDeviceManager.Instance.GetDevices()?.Any() == true;
        }
        catch
        {
            return false;
        }
    }

    private static MediaDevice GetDevice()
    {
        return MediaDeviceManager.Instance.GetDevices()?.FirstOrDefault()
            ?? throw new InvalidOperationException("No MTP device found.");
    }

    private static DeviceSnapshot Snapshot(MediaDevice device)
    {
        return new DeviceSnapshot(device.DeviceId, DeviceName(device), ListFiles(device));
    }

    private static string UniqueFileName(MediaDevice device, string targetDirectory, string fileName)
    {
        var targetPath = $@"{targetDirectory}\{fileName}";
        if (!device.FileExists(targetPath))
            return fileName;

        var extension = Path.GetExtension(fileName);
        var name = Path.GetFileNameWithoutExtension(fileName);
        if (string.IsNullOrEmpty(name))
        {
            name = fileName;
            extension = "";
        }

        for (var suffix = 1; ; suffix++)
        {
            var candidate = $"{name} ({suffix}){extension}";
            if (!device.FileExists($@"{targetDirectory}\{candidate}"))
                return candidate;
        }
    }

    private static void TryDeleteFile(MediaDevice device, string path)
    {
        try
        {
            if (device.FileExists(path))
                device.DeleteFile(path);
        }
        catch
        {
        }
    }

    private static void DownloadFile(MediaDevice device, string remotePath, string destinationPath)
    {
        var destinationDirectory = Path.GetDirectoryName(destinationPath)
            ?? throw new ArgumentException("Choose a valid download destination.", nameof(destinationPath));
        var temporaryPath = Path.Combine(
            destinationDirectory,
            $".{Path.GetFileName(destinationPath)}.{Guid.NewGuid():N}.tmp");

        try
        {
            device.DownloadFile(remotePath, temporaryPath);
            File.Move(temporaryPath, destinationPath, true);
        }
        finally
        {
            if (File.Exists(temporaryPath))
                File.Delete(temporaryPath);
        }
    }

    private static string DeviceName(MediaDevice device)
    {
        return string.IsNullOrWhiteSpace(device.FriendlyName) ? "MTP device" : device.FriendlyName;
    }

    private static string DataBankPath(MediaDevice device)
    {
        var drive = device.GetDrives().FirstOrDefault()
            ?? throw new InvalidOperationException("Device storage not found.");
        var rootDirectory = drive.RootDirectory
            ?? throw new InvalidOperationException("Device storage root not found.");
        return $@"{rootDirectory.FullName.TrimEnd('\\')}\{DataBankRelativePath}";
    }

    private static List<string> ListFiles(MediaDevice device)
    {
        var path = DataBankPath(device);
        if (!device.DirectoryExists(path))
            return [];

        return device.GetDirectoryInfo(path)
            .EnumerateFiles()
            .Select(file => file.Name)
            .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }

    private static void Disconnect(MediaDevice device)
    {
        if (device.IsConnected)
            device.Disconnect();
    }
}
