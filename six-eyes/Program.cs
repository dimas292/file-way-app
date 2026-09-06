using Qt.MetaObject;
using Qt.Quick;

namespace six_eyes
{
    public class Program
    {
        internal static void Main(string[] args)
        {
            Qml.LoadFromRootModule("Main");
            Qml.WaitForExit();
            DeviceBackend.Current?.Dispose();
        }
    }
}
