Device (AXDL)
{
  Name (_HID, "ADXL345A")
  Name (_UID, 0x1)

  Method (_STA) {
    Return (0xf)
  }

  Name (_CRS, ResourceTemplate () {
    I2CSerialBus(0x53, ControllerInitiated, 400000, 
                 AddressingMode7Bit, "\\_SB.I2C3", 0, ResourceConsumer)
    GpioInt(Edge, ActiveHigh, Shared, PullDown, 0, "\\_SB.GPIO") {65}
  })

  Method(_DSM, 0x4, NotSerialized)
  {
    If(LEqual(Arg0, Buffer(0x10)
    {
      0x1e, 0x54, 0x81, 0x76, 0x27, 0x88, 0x39, 0x42, 0x8d, 0x9d, 0x36, 0xbe, 0x7f, 0xe1, 0x25, 0x42
    }))
    {
      If(LEqual(Arg2, Zero))
      {
        Return(Buffer(One)
        {
          0x03
        })
      }
      If(LEqual(Arg2, One))
      {
        Return(Buffer(0x4)
        {
          0x00, 0x01, 0x02, 0x03
        })
      }
    }
    Else
    {
      Return(Buffer(One)
      {
        0x00
      })
    }
  }
}

