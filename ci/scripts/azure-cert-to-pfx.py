#!/usr/bin/env python3
"""
Azure certificate helper for Terraform (service principal with client_certificate in tfvars).

Reads only the file path you pass via --tfvars (typically terraform.tfvars next to your
Terraform root). Does not load network configuration or call Azure APIs.

Requirements:
  - Python 3 with the ``cryptography`` package
  - ``openssl`` on PATH (used for PEM/PFX conversion and optional RSA text parsing)

Emits shell ``export`` statements on stdout suitable for: eval "$(python3 ... --tfvars PATH)"

Environment variables emitted (for HashiCorp Terraform / azurerm):
  ARM_CLIENT_CERTIFICATE_PATH, ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID,
  TF_VAR_client_secret (empty string; satisfies modules that still declare client_secret)
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional, Tuple

try:
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
except ImportError:
    print("Error: cryptography library not installed", file=sys.stderr)
    print("Install with: pip install cryptography", file=sys.stderr)
    sys.exit(1)


class CertificateConverter:
    """Handles Azure certificate extraction and conversion."""

    def __init__(self, tfvars_path: str, output_path: Optional[str] = None):
        self.tfvars_path = Path(tfvars_path)
        self.output_path = Path(output_path) if output_path else Path('/tmp/azure_cert.pfx')
        self.cert_pem_path = Path('/tmp/cert.pem')
        self.fixed_pem_path = Path('/tmp/fixed.pem')

        if not self.tfvars_path.exists():
            raise FileNotFoundError(f"Terraform tfvars file not found: {self.tfvars_path}")

    def extract_certificate(self) -> None:
        """Extract certificate from terraform.tfvars heredoc format."""
        print("Extracting certificate from terraform.tfvars...", file=sys.stderr)

        with open(self.tfvars_path, 'r') as f:
            content = f.read()

        # Extract certificate between heredoc markers
        cert_pattern = r'client_certificate = <<CLIENT_CERTIFICATE\n(.*?)\nCLIENT_CERTIFICATE'
        match = re.search(cert_pattern, content, re.DOTALL)

        if not match:
            raise ValueError("Could not find client_certificate in tfvars file")

        cert_data = match.group(1)

        with open(self.cert_pem_path, 'w') as f:
            f.write(cert_data)

        self.cert_pem_path.chmod(0o600)
        print(f"Certificate extracted to {self.cert_pem_path}", file=sys.stderr)

    def extract_azure_credentials(self) -> Tuple[str, str, str]:
        """Extract Azure credentials from terraform.tfvars."""
        print("Extracting Azure credentials...", file=sys.stderr)

        with open(self.tfvars_path, 'r') as f:
            content = f.read()

        client_id = re.search(r'client_id\s*=\s*"([^"]+)"', content)
        tenant_id = re.search(r'tenant_id\s*=\s*"([^"]+)"', content)
        subscription_id = re.search(r'subscription_id\s*=\s*"([^"]+)"', content)

        if not all([client_id, tenant_id, subscription_id]):
            raise ValueError("Could not extract all required Azure credentials from tfvars")

        return (
            client_id.group(1),
            tenant_id.group(1),
            subscription_id.group(1)
        )

    def fix_private_key(self) -> bool:
        """
        Attempt to load and fix private key.
        Returns True if successful, False if reconstruction needed.
        """
        print("Attempting to load private key...", file=sys.stderr)

        try:
            with open(self.cert_pem_path, 'rb') as f:
                pem_data = f.read()

            # Try standard load
            key = serialization.load_pem_private_key(
                pem_data,
                password=None,
                backend=default_backend()
            )

            # Success - write cleaned key
            clean_pem = key.private_bytes(
                encoding=serialization.Encoding.PEM,
                format=serialization.PrivateFormat.TraditionalOpenSSL,
                encryption_algorithm=serialization.NoEncryption()
            )

            with open(self.fixed_pem_path, 'wb') as f:
                f.write(clean_pem)

            print("Private key loaded and fixed successfully", file=sys.stderr)
            return True

        except ValueError as e:
            print(f"Standard key load failed: {e}", file=sys.stderr)
            print("Will attempt key reconstruction from prime components...", file=sys.stderr)
            return False
        except Exception as e:
            raise Exception(f"Error fixing private key: {e}") from e

    def reconstruct_private_key(self) -> None:
        """Reconstruct private key from prime components (for malformed keys)."""
        print("Reconstructing private key from RSA components...", file=sys.stderr)

        # Get key text representation
        try:
            result = subprocess.run(
                ['openssl', 'rsa', '-in', str(self.cert_pem_path), '-text', '-noout'],
                capture_output=True,
                text=True,
                check=False
            )
            key_text = result.stdout

            if not key_text:
                raise Exception("Could not extract key text representation")

        except FileNotFoundError as e:
            raise Exception("OpenSSL not found. Please install OpenSSL.") from e

        # Extract RSA components
        def extract_component(name: str, text: str) -> Optional[int]:
            """Extract hexadecimal component from OpenSSL text output."""
            # Special case for publicExponent
            if name.lower() == "publicexponent":
                match = re.search(
                    r'publicexponent:\s*\d+\s*\(0x([0-9a-f]+)\)',
                    text,
                    re.IGNORECASE
                )
                if match:
                    return int(match.group(1), 16)

            # Find component in text
            text_lower = text.lower()
            start_idx = text_lower.find(name.lower() + ":")

            if start_idx == -1:
                return None

            start_idx += len(name) + 1
            hex_str = ""

            for line in text[start_idx:].split('\n'):
                line = line.strip()
                if not line:
                    continue

                # Check if we've hit the next component
                if re.match(r'^[a-zA-Z0-9]+:$', line):
                    break

                # Extract hex digits
                clean_line = line.replace(':', '').replace(' ', '')
                if re.match(r'^[0-9a-fA-F]+$', clean_line):
                    hex_str += clean_line
                elif hex_str:
                    break

            return int(hex_str, 16) if hex_str else None

        # Extract all components
        modulus = extract_component('modulus', key_text)
        public_exponent = extract_component('publicExponent', key_text)
        private_exponent = extract_component('privateExponent', key_text)
        prime1 = extract_component('prime1', key_text)
        prime2 = extract_component('prime2', key_text)

        if not all([modulus, public_exponent, private_exponent, prime1, prime2]):
            missing = []
            if not modulus:
                missing.append('modulus')
            if not public_exponent:
                missing.append('publicExponent')
            if not private_exponent:
                missing.append('privateExponent')
            if not prime1:
                missing.append('prime1')
            if not prime2:
                missing.append('prime2')
            raise Exception(f"Could not extract RSA components: {', '.join(missing)}")

        print("Extracted RSA components:", file=sys.stderr)
        print(f"  - Modulus: {len(bin(modulus))-2} bits", file=sys.stderr)
        print(f"  - Prime1 (p): {len(bin(prime1))-2} bits", file=sys.stderr)
        print(f"  - Prime2 (q): {len(bin(prime2))-2} bits", file=sys.stderr)

        # Reconstruct key
        public_numbers = rsa.RSAPublicNumbers(public_exponent, modulus)
        private_numbers = rsa.RSAPrivateNumbers(
            p=prime1,
            q=prime2,
            d=private_exponent,
            dmp1=rsa.rsa_crt_dmp1(private_exponent, prime1),
            dmq1=rsa.rsa_crt_dmq1(private_exponent, prime2),
            iqmp=rsa.rsa_crt_iqmp(prime1, prime2),
            public_numbers=public_numbers
        )

        key = private_numbers.private_key(default_backend())

        # Write reconstructed key
        clean_pem = key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.TraditionalOpenSSL,
            encryption_algorithm=serialization.NoEncryption()
        )

        with open(self.fixed_pem_path, 'wb') as f:
            f.write(clean_pem)

        print("Private key reconstructed successfully", file=sys.stderr)

    def convert_to_pfx(self) -> None:
        """Convert PEM certificate to PFX format."""
        print(f"Converting to PFX format: {self.output_path}", file=sys.stderr)

        # Extract certificate part (without private key) from original PEM
        cert_only_path = Path('/tmp/cert_only.pem')
        try:
            result = subprocess.run(
                ['openssl', 'x509', '-in', str(self.cert_pem_path)],
                capture_output=True,
                check=True
            )
            cert_only_path.write_bytes(result.stdout)
            print("Extracted certificate", file=sys.stderr)
        except subprocess.CalledProcessError as e:
            err = e.stderr.decode() if isinstance(e.stderr, (bytes, bytearray)) else (e.stderr or '')
            raise Exception(f"Failed to extract certificate: {err}") from e

        # Combine fixed private key with certificate
        combined_pem_path = Path('/tmp/combined.pem')
        try:
            # Read fixed key
            with open(self.fixed_pem_path, 'rb') as f:
                fixed_key = f.read()

            # Read certificate
            with open(cert_only_path, 'rb') as f:
                cert_data = f.read()

            # Combine: key first, then certificate
            with open(combined_pem_path, 'wb') as f:
                f.write(fixed_key)
                f.write(cert_data)

            combined_pem_path.chmod(0o600)
            print("Combined certificate and fixed key", file=sys.stderr)
        except Exception as e:
            raise Exception(f"Failed to combine certificate and key: {e}") from e

        try:
            # Use OpenSSL to convert combined PEM to PFX with empty password
            subprocess.run(
                [
                    'openssl', 'pkcs12', '-export',
                    '-in', str(combined_pem_path),
                    '-out', str(self.output_path),
                    '-passout', 'pass:',
                    '-legacy'  # OpenSSL3 compatibility
                ],
                check=True,
                capture_output=True
            )

            self.output_path.chmod(0o600)
            print(f"PFX certificate created: {self.output_path}", file=sys.stderr)

        except subprocess.CalledProcessError as e:
            err = e.stderr.decode() if isinstance(e.stderr, (bytes, bytearray)) else (e.stderr or '')
            raise Exception(f"Failed to convert to PFX: {err}") from e
        except FileNotFoundError as e:
            raise Exception("OpenSSL not found. Please install OpenSSL.") from e
        finally:
            # Cleanup temp files
            if cert_only_path.exists():
                cert_only_path.unlink()
            if combined_pem_path.exists():
                combined_pem_path.unlink()

    def set_environment_variables(
        self,
        client_id: str,
        tenant_id: str,
        subscription_id: str
    ) -> None:
        """Print export commands for Azure authentication environment variables."""
        print("\n" + "=" * 60, file=sys.stderr)
        print("Azure authentication environment variables", file=sys.stderr)
        print("=" * 60, file=sys.stderr)

        # Print export commands to stdout (for eval)
        print(f"export ARM_CLIENT_CERTIFICATE_PATH='{self.output_path}'")
        print(f"export ARM_CLIENT_ID='{client_id}'")
        print(f"export ARM_TENANT_ID='{tenant_id}'")
        print(f"export ARM_SUBSCRIPTION_ID='{subscription_id}'")
        print("export TF_VAR_client_secret=''")

        print("=" * 60, file=sys.stderr)
        print("\nEnvironment exports written to stdout (eval to apply)", file=sys.stderr)
        print(f"   Certificate: {self.output_path}", file=sys.stderr)
        print(f"   Client ID: {client_id[:8]}...", file=sys.stderr)
        print(f"   Tenant ID: {tenant_id[:8]}...", file=sys.stderr)
        print(f"   Subscription ID: {subscription_id[:8]}...", file=sys.stderr)

    def cleanup_temp_files(self) -> None:
        """Remove temporary files."""
        for path in [self.cert_pem_path, self.fixed_pem_path]:
            if path.exists():
                path.unlink()

    def convert(self) -> Tuple[str, str, str]:
        """
        Main conversion workflow.
        Returns: (client_id, tenant_id, subscription_id)
        """
        try:
            self.extract_certificate()
            client_id, tenant_id, subscription_id = self.extract_azure_credentials()

            if not self.fix_private_key():
                self.reconstruct_private_key()

            self.convert_to_pfx()
            self.set_environment_variables(client_id, tenant_id, subscription_id)

            return (client_id, tenant_id, subscription_id)

        finally:
            self.cleanup_temp_files()


def main():
    parser = argparse.ArgumentParser(
        description='Convert Azure service principal certificate from PEM to PFX format',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 azure-cert-to-pfx.py --tfvars terraform.tfvars
  python3 azure-cert-to-pfx.py --tfvars terraform.tfvars --output /path/to/cert.pfx
  eval "$(python3 azure-cert-to-pfx.py --tfvars terraform.tfvars)"
        """
    )

    parser.add_argument(
        '--tfvars',
        required=True,
        help='Path to terraform.tfvars file containing Azure certificate'
    )

    parser.add_argument(
        '--output',
        help='Output path for PFX file (default: /tmp/azure_cert.pfx)'
    )

    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose traceback on errors'
    )

    args = parser.parse_args()

    try:
        converter = CertificateConverter(args.tfvars, args.output)
        converter.convert()
        sys.exit(0)

    except Exception as e:
        print(f"\nError: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
