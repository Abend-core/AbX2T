using System;
using System.Diagnostics;
using System.IO;
using System.Xml;

class Program
{
    static int Main(string[] args)
    {
        if (args.Length < 2)
        {
            Console.Error.WriteLine("Usage: convert.exe <source.docx|source.doc> <output.pdf>");
            return 1;
        }

        string input  = Path.GetFullPath(args[0]);
        string output = Path.GetFullPath(args[1]);

        if (!File.Exists(input))
        {
            Console.Error.WriteLine($"Erreur: fichier source introuvable: {input}");
            return 1;
        }

        string inputExt = Path.GetExtension(input).ToLowerInvariant();
        if (inputExt != ".docx" && inputExt != ".doc")
        {
            Console.Error.WriteLine($"Erreur: format non supporte ({inputExt}). Utiliser .doc ou .docx");
            return 1;
        }

        if (Path.GetExtension(output).ToLowerInvariant() != ".pdf")
        {
            Console.Error.WriteLine("Erreur: la sortie doit etre un .pdf");
            return 1;
        }

        // x2t.exe et ses assets sont a cote de convert.exe
        string exeDir      = AppContext.BaseDirectory;
        string x2tPath     = Path.Combine(exeDir, "x2t.exe");
        string allFonts    = Path.Combine(exeDir, "AllFonts.js");
        string sdkjsDir    = Path.Combine(exeDir, "sdkjs");

        if (!File.Exists(x2tPath))
        {
            Console.Error.WriteLine($"Erreur: x2t.exe introuvable dans {exeDir}");
            return 1;
        }
        if (!File.Exists(allFonts))
        {
            Console.Error.WriteLine($"Erreur: AllFonts.js introuvable dans {exeDir}");
            return 1;
        }

        string outputDir = Path.GetDirectoryName(output);
        if (!string.IsNullOrEmpty(outputDir))
            Directory.CreateDirectory(outputDir);

        string configPath = Path.Combine(Path.GetTempPath(), $"x2t_{Guid.NewGuid():N}.xml");
        try
        {
            WriteConfig(configPath, input, output, allFonts, exeDir, sdkjsDir);

            var psi = new ProcessStartInfo
            {
                FileName               = x2tPath,
                Arguments              = $"\"{configPath}\"",
                WorkingDirectory       = exeDir,
                UseShellExecute        = false,
                RedirectStandardOutput = true,
                RedirectStandardError  = true,
            };

            using var proc = Process.Start(psi)!;
            string stdout = proc.StandardOutput.ReadToEnd();
            string stderr = proc.StandardError.ReadToEnd();
            proc.WaitForExit();

            if (proc.ExitCode != 0)
            {
                Console.Error.WriteLine($"Erreur x2t (code {proc.ExitCode})");
                if (!string.IsNullOrWhiteSpace(stderr)) Console.Error.WriteLine(stderr);
                if (!string.IsNullOrWhiteSpace(stdout)) Console.Error.WriteLine(stdout);
                return proc.ExitCode;
            }

            if (!File.Exists(output))
            {
                Console.Error.WriteLine("Erreur: conversion terminee mais PDF absent");
                return 1;
            }

            Console.WriteLine($"OK: {output}");
            return 0;
        }
        finally
        {
            if (File.Exists(configPath))
                File.Delete(configPath);
        }
    }

    static void WriteConfig(string config, string input, string output,
                            string allFonts, string fontDir, string sdkjsDir)
    {
        var settings = new XmlWriterSettings { Indent = true };
        using var w = XmlWriter.Create(config, settings);
        w.WriteStartDocument();
        w.WriteStartElement("TaskQueueDataConvert");
        w.WriteElementString("m_sFileFrom",     input);
        w.WriteElementString("m_sFileTo",       output);
        w.WriteElementString("m_sAllFontsPath", allFonts);
        w.WriteElementString("m_sFontDir",      fontDir);
        w.WriteElementString("m_sThemeDir",     sdkjsDir);
        w.WriteEndElement();
        w.WriteEndDocument();
    }
}
