def hex_to_uint256(hex_key: str) -> int:
    # Strip 0x if present
    hex_key = hex_key.lower().replace("0x", "")
    
    # Validate length: should be 64 hex chars = 256 bits
    if len(hex_key) != 64:
        raise ValueError("Invalid private key length (expected 64 hex characters)")

    return int(hex_key, 16)


if __name__ == "__main__":
    # Example: replace this with your real private key
    hex_key = input("Enter your private key (0x... or plain hex): ").strip()
    
    try:
        uint256_value = hex_to_uint256(hex_key)
        print("\nYour uint256 private key:")
        print(uint256_value)
    except ValueError as e:
        print(f"Error: {e}")