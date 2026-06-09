
import subprocess
import sys
from pathlib import Path


def main():
    spec_file = Path(__file__).parent / "DirectoryScanner.spec"
    
    if not spec_file.exists():
        print(f"Error: Spec file not found: {spec_file}")
        sys.exit(1)
    
    print("Building Rootline Atlas...")
    print(f"Spec file: {spec_file}")
    
    try:
        result = subprocess.run(
            [sys.executable, "-m", "PyInstaller", str(spec_file)],
            cwd=str(Path(__file__).parent),
            capture_output=False,
            text=True,
            check=True
        )
        print("\n✅ Build complete!")
        print(f"Output: {Path(__file__).parent / 'dist' / 'Rootline Atlas.exe'}")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Build failed with exit code {e.returncode}")
        sys.exit(1)
    except FileNotFoundError:
        print("\n❌ Error: PyInstaller not found. Install with: pip install pyinstaller")
        sys.exit(1)


if __name__ == "__main__":
    main()
