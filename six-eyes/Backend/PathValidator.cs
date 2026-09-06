namespace six_eyes;

internal static class PathValidator
{
    public static string LocalPath(string pathOrUrl)
    {
        if (Uri.TryCreate(pathOrUrl, UriKind.Absolute, out var uri) && uri.IsFile)
            return uri.LocalPath;
        return Path.GetFullPath(pathOrUrl);
    }

    public static void ValidateFileName(string fileName)
    {
        if (string.IsNullOrWhiteSpace(fileName) ||
            fileName is "." or ".." ||
            Path.GetFileName(fileName) != fileName ||
            fileName.IndexOfAny(['/', '\0', '\\']) >= 0)
        {
            throw new ArgumentException("Invalid device filename.", nameof(fileName));
        }
    }
}
