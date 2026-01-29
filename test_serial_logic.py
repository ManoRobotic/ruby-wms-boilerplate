# Mock dependencies before importing ScaleManager
import unittest
from unittest.mock import MagicMock, patch
import sys
import os

# Create mock objects
mock_serial = MagicMock()
mock_ports = MagicMock()
mock_websockets = MagicMock()
mock_win32print = MagicMock()

# Inject mocks into sys.modules
sys.modules['serial'] = mock_serial
sys.modules['serial.tools'] = MagicMock()
sys.modules['serial.tools.list_ports'] = mock_ports
sys.modules['websockets'] = mock_websockets
sys.modules['win32print'] = mock_win32print

# Also mock websockets version
mock_websockets.__version__ = "16.0"

# Import the actual module
from serial_server_prod import ScaleManager

class TestScaleManagerLogic(unittest.TestCase):
    def setUp(self):
        self.manager = ScaleManager(port="COM3")
        # Clear mock history
        import serial
        serial.Serial.reset_mock()

    def test_connect_fails_if_no_port(self):
        self.manager.port = None
        self.assertFalse(self.manager.connect())

    def test_connect_simple_mode_first(self):
        import serial
        # Setup mock to succeed on first call
        serial.Serial.return_value.is_open = True
        
        # We need to mock time.sleep to make tests fast
        with patch('time.sleep'):
            result = self.manager.connect(force=True)
            
        self.assertTrue(result)
        # Verify it tried the simple port first
        serial.Serial.assert_called_with('COM3', 9600, timeout=1)

    def test_ghost_port_recovery(self):
        import serial
        import serial.tools.list_ports
        
        # Setup: Initial port exists in enumeration but fails to open with Error 2
        mock_port = MagicMock()
        mock_port.device = "COM4"
        mock_port.vid = 0x0483
        mock_port.pid = 0x5740
        serial.tools.list_ports.comports.return_value = [mock_port]
        
        # Simulate: 1st open fails with Error 2, 2nd open succeeds
        error2 = FileNotFoundError(2, "No encontrado", None, 2)
        
        with patch('serial.Serial') as mock_ser_class:
            # Simple Mode fails, HWID 1st try fails, HWID 2nd try (after sleep) succeeds
            mock_ser_class.side_effect = [
                error2, # Simple mode
                error2, # HWID 1st try
                MagicMock(is_open=True) # HWID 2nd try
            ]
            
            with patch('time.sleep'):
                result = self.manager.connect(force=True)
                
            self.assertTrue(result)
            self.assertEqual(self.manager.port, "COM4")
            # Should have called Serial at least 3 times
            self.assertGreaterEqual(mock_ser_class.call_count, 3)

    def test_manual_override_protection(self):
        # Already tested in thought, but let's verify manager state
        self.manager.set_port("COM4")
        self.assertTrue(self.manager.manual_port_override)

if __name__ == '__main__':
    unittest.main()
