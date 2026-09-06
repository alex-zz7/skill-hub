using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using SkillHub.Core;

namespace SkillHub.App;

public partial class App : Application
{
    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            var store = new CatalogStore(new HubPaths(home));
            desktop.MainWindow = new MainWindow(store);
        }

        base.OnFrameworkInitializationCompleted();
    }
}
