namespace six_eyes;

internal sealed class DeviceOperationCoordinator : IDisposable
{
    private readonly SemaphoreSlim operationLock = new(1, 1);
    private readonly CancellationTokenSource lifetime = new();
    private bool disposed;

    public async Task RunAsync<T>(Func<T> operation, Action started, Action<T> completed)
    {
        ObjectDisposedException.ThrowIf(disposed, this);
        await operationLock.WaitAsync(lifetime.Token).ConfigureAwait(false);
        try
        {
            started();
            var result = await Task.Run(operation, lifetime.Token).ConfigureAwait(false);
            completed(result);
        }
        finally
        {
            operationLock.Release();
        }
    }

    public void Dispose()
    {
        if (disposed)
            return;

        disposed = true;
        lifetime.Cancel();
        lifetime.Dispose();
    }
}
