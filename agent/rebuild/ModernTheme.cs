using System.Drawing.Drawing2D;

namespace AandT.Agent.UI;

/// <summary>
/// Premium A&T Printix theme. Visual-only: does not touch discovery, activation,
/// local settings, the Supabase payload or the notification-area runtime.
/// </summary>
internal static class ModernTheme
{
    private static bool _lightMode;

    public static void Apply(Form form)
    {
        form.Text = "A&T Printix | Smart Printer Control";
        form.ClientSize = new Size(1220, 790);
        form.MinimumSize = new Size(1080, 690);
        form.BackColor = Background;
        form.ForeColor = Text;
        form.Font = new Font("Segoe UI", 9.25F);
        form.DoubleBuffered = true;

        var header = form.Controls.OfType<Panel>().FirstOrDefault(p => p.Dock == DockStyle.Top);
        if (header is not null)
        {
            header.Height = 88;
            header.BackColor = Header;
            header.Tag = "at-header";
            header.Paint -= HeaderPaint;
            header.Paint += HeaderPaint;

            var labels = header.Controls.OfType<Label>().ToList();
            if (labels.Count > 0)
            {
                labels[0].Text = "A&T PRINTIX";
                labels[0].Location = new Point(84, 13);
                labels[0].Font = new Font("Segoe UI Semibold", 19F, FontStyle.Bold);
                labels[0].ForeColor = _lightMode ? Color.FromArgb(16, 50, 71) : Color.FromArgb(242, 249, 255);
                labels[0].BackColor = Color.Transparent;
                labels[0].Tag = "at-hero";
            }
            if (labels.Count > 1)
            {
                labels[1].Text = "SMART PRINTER CONTROL   /   WINDOWS AGENT";
                labels[1].Location = new Point(86, 48);
                labels[1].Font = new Font("Segoe UI", 8.25F, FontStyle.Bold);
                labels[1].ForeColor = Muted;
                labels[1].BackColor = Color.Transparent;
                labels[1].Tag = "at-subtitle";
            }

            if (!header.Controls.OfType<Panel>().Any(p => Equals(p.Tag, "at-logo")))
            {
                var logo = new Panel
                {
                    Location = new Point(18, 17),
                    Size = new Size(50, 50),
                    BackColor = _lightMode ? Color.FromArgb(218, 240, 250) : Color.FromArgb(17, 56, 78),
                    Tag = "at-logo"
                };
                logo.Paint += (_, e) =>
                {
                    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
                    using var pen = new Pen(Accent, 1.6F);
                    e.Graphics.DrawRectangle(pen, 1, 1, logo.Width - 3, logo.Height - 3);
                    using var brush = new SolidBrush(Accent);
                    using var font = new Font("Segoe UI Semibold", 12F, FontStyle.Bold);
                    var text = "A&T";
                    var size = e.Graphics.MeasureString(text, font);
                    e.Graphics.DrawString(text, font, brush, (logo.Width - size.Width) / 2, (logo.Height - size.Height) / 2);
                };
                header.Controls.Add(logo);
                logo.BringToFront();
            }

            var version = header.Controls.OfType<Label>().FirstOrDefault(x => Equals(x.Tag, "at-version"));
            if (version is null)
            {
                version = new Label
                {
                    Tag = "at-version",
                    AutoSize = false,
                    Size = new Size(138, 30),
                    Text = "AGENT  v" + Program.AppVersion,
                    TextAlign = ContentAlignment.MiddleCenter,
                    Font = new Font("Segoe UI Semibold", 8F, FontStyle.Bold),
                    Anchor = AnchorStyles.Top | AnchorStyles.Right
                };
                header.Controls.Add(version);
            }
            version.Location = new Point(Math.Max(640, header.ClientSize.Width - 322), 27);
            version.BackColor = _lightMode ? Color.FromArgb(218, 239, 249) : Color.FromArgb(20, 56, 75);
            version.ForeColor = Accent;

            var themeButton = header.Controls.OfType<Button>().FirstOrDefault(x => Equals(x.Tag, "at-theme"));
            if (themeButton is null)
            {
                themeButton = new Button
                {
                    Tag = "at-theme",
                    Size = new Size(148, 34),
                    Anchor = AnchorStyles.Top | AnchorStyles.Right,
                    FlatStyle = FlatStyle.Flat,
                    Cursor = Cursors.Hand,
                    Font = new Font("Segoe UI Semibold", 8F, FontStyle.Bold)
                };
                themeButton.Click += (_, _) =>
                {
                    _lightMode = !_lightMode;
                    themeButton.Text = _lightMode ? "☾  MODO OSCURO" : "☼  MODO CLARO";
                    Apply(form);
                    header.Invalidate();
                };
                header.Controls.Add(themeButton);
            }
            themeButton.Text = _lightMode ? "☾  MODO OSCURO" : "☼  MODO CLARO";
            themeButton.Location = new Point(header.ClientSize.Width - 165, 25);
            themeButton.BackColor = Card;
            themeButton.ForeColor = Accent;
        }

        foreach (Control control in form.Controls)
            ApplyControl(control);
    }

    private static void HeaderPaint(object? sender, PaintEventArgs e)
    {
        if (sender is not Panel panel || panel.ClientSize.Width <= 0) return;
        var left = _lightMode ? Color.FromArgb(247, 251, 255) : Color.FromArgb(10, 23, 38);
        var right = _lightMode ? Color.FromArgb(231, 242, 250) : Color.FromArgb(15, 43, 62);
        using var brush = new LinearGradientBrush(panel.ClientRectangle, left, right, 0F);
        e.Graphics.FillRectangle(brush, panel.ClientRectangle);
        using var pen = new Pen(_lightMode ? Color.FromArgb(205, 222, 235) : Color.FromArgb(35, 76, 101));
        e.Graphics.DrawLine(pen, 0, panel.Height - 1, panel.Width, panel.Height - 1);
    }

    private static void ApplyControl(Control control)
    {
        if (control is TabControl tabs)
        {
            tabs.BackColor = Background;
            tabs.ForeColor = Text;
            tabs.DrawMode = TabDrawMode.OwnerDrawFixed;
            tabs.SizeMode = TabSizeMode.Fixed;
            tabs.ItemSize = new Size(170, 40);
            tabs.Padding = new Point(16, 6);
            if (!Equals(tabs.Tag, "at-tabs"))
            {
                tabs.Tag = "at-tabs";
                tabs.DrawItem += (_, e) =>
                {
                    var selected = e.Index == tabs.SelectedIndex;
                    var fill = _lightMode
                        ? (selected ? Color.FromArgb(215, 239, 250) : Color.FromArgb(234, 243, 249))
                        : (selected ? Color.FromArgb(19, 62, 85) : Color.FromArgb(11, 25, 39));
                    var color = _lightMode
                        ? (selected ? Color.FromArgb(12, 91, 126) : Color.FromArgb(78, 102, 120))
                        : (selected ? Color.FromArgb(91, 222, 255) : Color.FromArgb(153, 179, 198));
                    using var brush = new SolidBrush(fill);
                    e.Graphics.FillRectangle(brush, e.Bounds);
                    TextRenderer.DrawText(e.Graphics, tabs.TabPages[e.Index].Text.ToUpperInvariant(),
                        new Font("Segoe UI Semibold", 8.5F, FontStyle.Bold), e.Bounds, color,
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
                    if (selected)
                    {
                        using var line = new Pen(Accent, 3F);
                        e.Graphics.DrawLine(line, e.Bounds.Left + 20, e.Bounds.Bottom - 2, e.Bounds.Right - 20, e.Bounds.Bottom - 2);
                    }
                };
            }
        }
        else if (control is TabPage page)
        {
            page.BackColor = Background;
            page.ForeColor = Text;
            page.Padding = new Padding(8);
        }
        else if (control is DataGridView grid)
        {
            grid.BackgroundColor = Panel;
            grid.BorderStyle = BorderStyle.None;
            grid.EnableHeadersVisualStyles = false;
            grid.ColumnHeadersBorderStyle = DataGridViewHeaderBorderStyle.None;
            grid.ColumnHeadersHeight = 44;
            grid.ColumnHeadersDefaultCellStyle.BackColor = Card;
            grid.ColumnHeadersDefaultCellStyle.ForeColor = Accent;
            grid.ColumnHeadersDefaultCellStyle.Font = new Font("Segoe UI Semibold", 8F, FontStyle.Bold);
            grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = Card;
            grid.DefaultCellStyle.BackColor = Panel;
            grid.DefaultCellStyle.ForeColor = Text;
            grid.DefaultCellStyle.SelectionBackColor = Selection;
            grid.DefaultCellStyle.SelectionForeColor = Color.White;
            grid.DefaultCellStyle.Font = new Font("Segoe UI", 8.5F);
            grid.DefaultCellStyle.Padding = new Padding(6, 0, 6, 0);
            grid.AlternatingRowsDefaultCellStyle.BackColor = _lightMode ? Color.FromArgb(246, 250, 253) : Color.FromArgb(16, 34, 51);
            grid.AlternatingRowsDefaultCellStyle.ForeColor = Text;
            grid.GridColor = Border;
            grid.RowHeadersVisible = false;
        }
        else if (control is Button button)
        {
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderSize = 1;
            button.FlatAppearance.BorderColor = Border;
            button.FlatAppearance.MouseOverBackColor = Selection;
            button.UseVisualStyleBackColor = false;
            button.BackColor = Card;
            button.ForeColor = Accent;
            button.Cursor = Cursors.Hand;
            button.Font = new Font("Segoe UI Semibold", 8.5F, FontStyle.Bold);
            var caption = button.Text.ToUpperInvariant();
            if (caption.Contains("QUITAR") || caption.Contains("ELIMINAR"))
            {
                button.BackColor = _lightMode ? Color.FromArgb(255, 237, 239) : Color.FromArgb(82, 35, 46);
                button.ForeColor = _lightMode ? Color.FromArgb(154, 42, 57) : Color.FromArgb(255, 170, 180);
            }
            else if (caption.Contains("BUSCAR") || caption.Contains("ESCANEAR") || caption.Contains("ACTIVAR") || caption.Contains("GUARDAR"))
                button.BackColor = _lightMode ? Color.FromArgb(215, 241, 251) : Color.FromArgb(17, 75, 101);
        }
        else if (control is TextBox textBox)
        {
            textBox.BackColor = Input;
            textBox.ForeColor = Text;
            textBox.BorderStyle = BorderStyle.FixedSingle;
            textBox.Font = new Font("Segoe UI", 9F);
        }
        else if (control is ComboBox combo)
        {
            combo.BackColor = Input;
            combo.ForeColor = Text;
            combo.FlatStyle = FlatStyle.Flat;
            combo.Font = new Font("Segoe UI", 9F);
        }
        else if (control is ListBox list)
        {
            list.BackColor = Input;
            list.ForeColor = Text;
            list.BorderStyle = BorderStyle.FixedSingle;
        }
        else if (control is GroupBox group)
        {
            group.BackColor = Background;
            group.ForeColor = Accent;
            group.Font = new Font("Segoe UI Semibold", 9F, FontStyle.Bold);
        }
        else if (control is CheckBox check)
        {
            check.BackColor = Color.Transparent;
            check.ForeColor = Text;
        }
        else if (control is Label label)
        {
            label.ForeColor = Equals(label.Tag, "at-hero") ? HeroText :
                Equals(label.Tag, "at-subtitle") ? Muted :
                Equals(label.Tag, "at-version") ? Accent : Muted;
        }
        else if (control is Panel panel)
        {
            panel.BackColor = Equals(panel.Tag, "at-header") ? Header :
                Equals(panel.Tag, "at-logo") ? Card : Panel;
        }

        foreach (Control child in control.Controls)
            ApplyControl(child);
    }

    private static Color Background => _lightMode ? Color.FromArgb(241, 247, 251) : Color.FromArgb(7, 16, 28);
    private static Color Header => _lightMode ? Color.FromArgb(241, 248, 252) : Color.FromArgb(10, 23, 38);
    private static Color Panel => _lightMode ? Color.White : Color.FromArgb(13, 27, 42);
    private static Color Card => _lightMode ? Color.FromArgb(229, 239, 247) : Color.FromArgb(17, 38, 56);
    private static Color Input => _lightMode ? Color.White : Color.FromArgb(9, 23, 37);
    private static Color Accent => _lightMode ? Color.FromArgb(17, 105, 145) : Color.FromArgb(76, 216, 255);
    private static Color Selection => _lightMode ? Color.FromArgb(18, 54, 76) : Color.FromArgb(17, 54, 76);
    private static Color Border => _lightMode ? Color.FromArgb(220, 234, 244) : Color.FromArgb(31, 54, 73);
    private static Color Text => _lightMode ? Color.FromArgb(27, 53, 71) : Color.FromArgb(222, 236, 246);
    private static Color Muted => _lightMode ? Color.FromArgb(66, 91, 108) : Color.FromArgb(151, 176, 194);
    private static Color HeroText => _lightMode ? Color.FromArgb(16, 50, 71) : Color.FromArgb(242, 249, 255);
}
